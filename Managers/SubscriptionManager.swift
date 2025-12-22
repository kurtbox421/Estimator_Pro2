import Foundation
import FirebaseFirestore
import StoreKit
import SwiftUI
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let productIDs = [
        "estimator_pro_monthly",
        "estimator_pro_yearly"
    ]

    private enum ProductLoadingError: Error {
        case timeout
    }

    enum ProductLoadState {
        case idle
        case loading
        case loaded([Product])
        case failed(String)
    }

    @Published var products: [Product] = []
    @Published var isPro: Bool
    @Published var activeProductID: String?
    @Published var environment: String?
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var statusMessage: String?
    @Published var shouldShowPaywall: Bool = false
    @Published var productState: ProductLoadState = .idle
    @Published private(set) var productStateChangeToken: Int = 0

    private let db: Firestore
    private let session: SessionManager
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var resetToken: UUID?
    private var currentUID: String?
    private var currentBindingID: String?
    nonisolated(unsafe) private var subscriptionListener: ListenerRegistration?

    private var hasActiveStoreKitEntitlement = false
    private var hasSubscriptionBinding = false
    private var hasMatchingSubscriptionBinding = false
    private var hasRefreshedEntitlementsThisSession = false

    init(
        database: Firestore = Firestore.firestore(),
        session: SessionManager
    ) {
        self.db = database
        self.session = session
        self.isPro = false
        self.activeProductID = nil
        self.environment = nil

        resetToken = session.registerResetHandler { [weak self] in
            self?.clear()
        }
        session.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                self?.setUser(uid)
            }
            .store(in: &cancellables)
        setUser(session.uid)
    }

    deinit {
        updatesTask?.cancel()
        updatesTask = nil
        subscriptionListener?.remove()
        subscriptionListener = nil
        cancellables.removeAll()
        if let resetToken {
            let session = session
            Task { @MainActor in
                session.unregisterResetHandler(resetToken)
            }
        }
    }

    func loadProducts(timeout: TimeInterval = 10) async {
        isLoading = true
        setProductState(.loading)
        defer { isLoading = false }
        lastError = nil
        statusMessage = nil

        do {
            logStoreKitContext()
            let fetched = try await fetchProducts(within: timeout)
            let fetchedIDs = fetched.map(\.id)
            debugLog("[StoreKit] Retrieved product ids:", fetchedIDs)
            debugLog("[StoreKit] Returned product count:", fetched.count)
            await logProductFetchDebug(requestedIDs: Self.productIDs, returnedIDs: fetchedIDs)

            guard !fetched.isEmpty else {
                logEmptyProductsContext()
                let message = "Products unavailable. Check network or product configuration."
                lastError = message
                setProductState(.failed(message))
                products = []
                return
            }

            let sorted = fetched.sorted { lhs, rhs in
                let lhsIndex = Self.productIDs.firstIndex(of: lhs.id) ?? .max
                let rhsIndex = Self.productIDs.firstIndex(of: rhs.id) ?? .max
                return lhsIndex < rhsIndex
            }

            let sortedIDs = sorted.map(\.id)
            debugLog("[StoreKit] Sorted product identifiers:", sortedIDs)
            products = sorted
            setProductState(.loaded(sorted))
        } catch ProductLoadingError.timeout {
            let message = "Unable to reach the App Store right now. Check your connection and try again."
            lastError = message
            setProductState(.failed(message))
        } catch {
            debugLog("[StoreKit] Product request failed:", error.localizedDescription)
            let message = error.localizedDescription.isEmpty
                ? "Something went wrong. Please try again."
                : error.localizedDescription
            lastError = message
            setProductState(.failed(message))
        }
    }

    func purchase(_ product: Product) async {
        guard !isLoading else { return }
        guard let uid = session.uid else {
            lastError = "Please sign in first."
            statusMessage = lastError
            debugLog("[Purchase] Blocked purchase: no signed-in user.")
            return
        }

        isLoading = true
        defer { isLoading = false }
        lastError = nil
        statusMessage = "Processing purchase…"

        do {
            let result = try await product.purchase()
            debugLog("[Purchase] Result:", result)
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    debugLog("[Purchase] Verified transaction:", transaction.id, "uid:", uid)
                    let bindingSaved = await persistSubscriptionBinding(uid: uid, transaction: transaction)
                    updateBindingState(saved: bindingSaved, currentUID: uid, transaction: transaction)
                    await transaction.finish()
                    _ = await refreshEntitlements()
                    statusMessage = "Thanks for subscribing to Pro!"
                    shouldShowPaywall = false
                case .unverified(_, let error):
                    debugLog("[Purchase] Verification failed:", error.localizedDescription, "uid:", uid)
                    lastError = "Purchase verification failed: \(error.localizedDescription)"
                    statusMessage = lastError
                }
            case .userCancelled:
                statusMessage = "Purchase cancelled."
            case .pending:
                lastError = "Purchase is pending. Please check your App Store purchases."
                statusMessage = lastError
            @unknown default:
                lastError = "Unknown purchase result. Please try again."
                statusMessage = lastError
            }
        } catch {
            let message = error.localizedDescription.isEmpty
                ? "Purchase failed. Please try again."
                : error.localizedDescription
            lastError = message
            statusMessage = message
            debugLog("[Purchase] Failed:", error.localizedDescription, "uid:", uid)
        }
    }

    func restorePurchases() async {
        guard !isLoading else { return }
        guard let uid = session.uid else {
            lastError = "Sign in to restore."
            statusMessage = lastError
            debugLog("[Restore] Blocked restore: no signed-in user.")
            return
        }

        isLoading = true
        defer { isLoading = false }
        lastError = nil
        statusMessage = "Checking App Store purchases…"

        do {
            try await AppStore.sync()
        } catch {
            let message = error.localizedDescription.isEmpty
                ? "Restore failed. Please try again."
                : error.localizedDescription
            lastError = message
            statusMessage = message
            debugLog("[Restore] AppStore.sync failed:", error.localizedDescription, "uid:", uid)
            return
        }

        let entitlement = await activeSubscriptionEntitlement()
        if let entitlement {
            debugLog("[Restore] Found entitlement:", entitlement.productID, "uid:", uid)
            let bindingSaved = await persistSubscriptionBinding(uid: uid, transaction: entitlement)
            updateBindingState(saved: bindingSaved, currentUID: uid, transaction: entitlement)
            _ = await refreshEntitlements()
            statusMessage = "Restored Estimator Pro (\(entitlement.productID))."
        } else {
            _ = await refreshEntitlements()
            statusMessage = "No purchases found to restore."
        }
    }

    @discardableResult
    func refreshEntitlementsIfNeeded() async -> Bool {
        guard !hasRefreshedEntitlementsThisSession else { return isPro }
        hasRefreshedEntitlementsThisSession = true
        return await refreshEntitlementsQuietly()
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
        let entitlement = await activeSubscriptionEntitlement()
        hasActiveStoreKitEntitlement = entitlement != nil
        activeProductID = entitlement?.productID
        environment = entitlement.map { environmentString(for: $0) }
        debugLog("[Entitlements] StoreKit active:", hasActiveStoreKitEntitlement, "uid:", session.uid ?? "nil")
        await refreshBinding(for: entitlement)
        updateProStatus()
        return isPro
    }

    @discardableResult
    private func refreshEntitlementsQuietly() async -> Bool {
        await refreshEntitlements()
    }

    private func activeSubscriptionEntitlement() async -> StoreKit.Transaction? {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }

            if isTransactionActive(transaction) {
                return transaction
            }
        }

        return nil
    }

    private func isTransactionActive(_ transaction: StoreKit.Transaction) -> Bool {
        if let expiration = transaction.expirationDate, expiration < Date() {
            return false
        }
        if transaction.revocationDate != nil {
            return false
        }

        return true
    }

    private func updateProStatus() {
        let newValue = hasActiveStoreKitEntitlement && hasMatchingSubscriptionBinding
        if isPro != newValue {
            isPro = newValue
        }
    }

    private func updateBindingStatusMessage(_ message: String?) {
        statusMessage = message
        if let message {
            lastError = message
        } else if lastError == "Subscription already linked to another account."
                    || lastError == "Subscription is linked to another account." {
            lastError = nil
        }
    }

    func presentPaywall(after delay: TimeInterval = 0) {
        let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)

        Task { @MainActor in
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            shouldShowPaywall = true
        }
    }

    func presentPaywallFromRoot(afterDismissing dismiss: DismissAction) {
        dismiss()
        Task { @MainActor in
            shouldShowPaywall = true
        }
    }

    private func setProductState(_ newState: ProductLoadState) {
        productState = newState
        productStateChangeToken &+= 1
    }

    private func handle(transactionResult: VerificationResult<StoreKit.Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            debugLog("[StoreKit] Transaction update verified:", transaction.id)
            await handleVerifiedTransactionUpdate(transaction)
        case .unverified(_, let error):
            debugLog("[StoreKit] Transaction update verification failed:", error.localizedDescription)
        }
    }

    private func handleVerifiedTransactionUpdate(_ transaction: StoreKit.Transaction) async {
        await refreshEntitlements()
        guard let uid = session.uid else {
            debugLog("[StoreKit] Skipping binding update: no signed-in user.")
            return
        }

        guard isTransactionActive(transaction) else {
            debugLog("[StoreKit] Skipping binding update: inactive transaction for uid:", uid)
            return
        }

        let bindingSaved = await persistSubscriptionBinding(uid: uid, transaction: transaction)
        updateBindingState(saved: bindingSaved, currentUID: uid, transaction: transaction)
        await transaction.finish()
    }

    private struct SubscriptionBinding {
        let uid: String
        let productId: String
        let expiresAt: Date?
        let updatedAt: Date?
    }

    private func refreshBinding(for entitlement: StoreKit.Transaction?) async {
        updateBindingStatusMessage(nil)
        hasSubscriptionBinding = false
        hasMatchingSubscriptionBinding = false

        guard let entitlement,
              let uid = session.uid else {
            stopSubscriptionListener()
            currentBindingID = nil
            return
        }

        let originalTransactionId = String(entitlement.originalID)
        if currentBindingID != originalTransactionId {
            startSubscriptionBindingListener(originalTransactionId: originalTransactionId, uid: uid)
            currentBindingID = originalTransactionId
        }

        if let binding = await fetchSubscriptionBinding(originalTransactionId: originalTransactionId) {
            applyBinding(binding, currentUID: uid)
            return
        }

        let saved = await persistSubscriptionBinding(uid: uid, transaction: entitlement)
        updateBindingState(saved: saved, currentUID: uid, transaction: entitlement)
    }

    private func fetchSubscriptionBinding(originalTransactionId: String) async -> SubscriptionBinding? {
        do {
            let snapshot = try await bindingDocRef(originalTransactionId: originalTransactionId).getDocument()
            guard let data = snapshot.data() else { return nil }
            guard let uid = data["uid"] as? String,
                  let productId = data["productId"] as? String else { return nil }
            let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
            return SubscriptionBinding(uid: uid, productId: productId, expiresAt: expiresAt, updatedAt: updatedAt)
        } catch {
            logFirestoreError(error, context: "subscription binding fetch", uid: session.uid)
            return nil
        }
    }

    private func applyBinding(_ binding: SubscriptionBinding, currentUID: String) {
        guard !binding.uid.isEmpty else {
            hasSubscriptionBinding = false
            hasMatchingSubscriptionBinding = false
            updateBindingStatusMessage(nil)
            return
        }

        hasSubscriptionBinding = true
        hasMatchingSubscriptionBinding = binding.uid == currentUID
        if hasMatchingSubscriptionBinding {
            updateBindingStatusMessage(nil)
            return
        }

        debugLog("[Firestore] Subscription binding mismatch. boundUID:", binding.uid, "currentUID:", currentUID)
        updateBindingStatusMessage("Subscription is linked to another account.")
    }

    private func updateBindingState(saved: Bool, currentUID: String, transaction: StoreKit.Transaction) {
        if saved {
            let binding = SubscriptionBinding(
                uid: currentUID,
                productId: transaction.productID,
                expiresAt: transaction.expirationDate,
                updatedAt: Date()
            )
            applyBinding(binding, currentUID: currentUID)
        } else {
            hasSubscriptionBinding = false
            hasMatchingSubscriptionBinding = false
        }
        updateProStatus()
    }

    private func fetchProducts(within timeout: TimeInterval) async throws -> [Product] {
        let requestedIDs = Self.productIDs
        let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
        let logger = debugLog

        return try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask {
                logger("[StoreKit] Requesting products:", requestedIDs)
                let products = try await Product.products(for: requestedIDs)
                logger("[StoreKit] StoreKit 2 product ids:", products.map(\.id))
                return products
            }

            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                throw ProductLoadingError.timeout
            }

            guard let result = try await group.next() else { throw ProductLoadingError.timeout }
            group.cancelAll()
            return result
        }
    }

    private func persistSubscriptionBinding(uid: String, transaction: StoreKit.Transaction) async -> Bool {
        let environmentValue = environmentString(for: transaction)
        let originalTransactionId = String(transaction.originalID)
        let docRef = bindingDocRef(originalTransactionId: originalTransactionId)
        do {
            let snapshot = try await docRef.getDocument()
            if let data = snapshot.data(),
               let boundUID = data["uid"] as? String,
               boundUID != uid {
                debugLog("[Firestore] Subscription binding already linked to uid:", boundUID, "transaction:", originalTransactionId)
                updateBindingStatusMessage("Subscription already linked to another account.")
                return false
            }

            let data: [String: Any] = [
                "uid": uid,
                "productId": transaction.productID,
                "originalTransactionId": originalTransactionId,
                "transactionId": String(transaction.id),
                "appAccountToken": transaction.appAccountToken?.uuidString ?? NSNull(),
                "purchaseDate": Timestamp(date: transaction.purchaseDate),
                "expiresAt": transaction.expirationDate.map { Timestamp(date: $0) } ?? NSNull(),
                "environment": environmentValue,
                "updatedAt": FieldValue.serverTimestamp()
            ]

            debugLog("[Firestore] Writing subscription binding for uid:", uid, "transaction:", originalTransactionId)
            print("[Data] SubscriptionManager uid=\(uid) path=subscriptionBindings/\(originalTransactionId) action=write")
            try await docRef.setData(data, merge: true)
            return true
        } catch {
            logFirestoreError(error, context: "subscription binding write", uid: uid)
            return false
        }
    }

    private func bindingDocRef(originalTransactionId: String) -> DocumentReference {
        db.collection("subscriptionBindings")
            .document(originalTransactionId)
    }

    private func environmentString(for transaction: StoreKit.Transaction) -> String {
        if #available(iOS 17.0, *) {
            let environmentValue = String(describing: transaction.environment).lowercased()
            if environmentValue.contains("xcode") {
                return "xcode"
            }
            if environmentValue.contains("sandbox") {
                return "sandbox"
            }
            if environmentValue.contains("production") {
                return "production"
            }
            return "unknown"
        }

        return "unknown"
    }

    private func startEntitlementListeners() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in StoreKit.Transaction.updates {
                await self.handle(transactionResult: result)
            }
        }
    }

    nonisolated private func stopEntitlementListeners() {
        updatesTask?.cancel()
        updatesTask = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            isLoading = false
            products = []
            lastError = nil
            statusMessage = nil
            setProductState(.idle)
            activeProductID = nil
            environment = nil
            shouldShowPaywall = false
            hasActiveStoreKitEntitlement = false
            hasSubscriptionBinding = false
            hasMatchingSubscriptionBinding = false
            hasRefreshedEntitlementsThisSession = false
            currentBindingID = nil
        }
    }

    nonisolated private func stopSubscriptionListener() {
        subscriptionListener?.remove()
        subscriptionListener = nil
    }

    private func startSubscriptionBindingListener(originalTransactionId: String, uid: String) {
        stopSubscriptionListener()
        print("[Data] SubscriptionManager uid=\(uid) path=subscriptionBindings/\(originalTransactionId) action=listen")

        subscriptionListener = bindingDocRef(originalTransactionId: originalTransactionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        self.logFirestoreError(error, context: "subscription binding listener", uid: uid)
                        return
                    }

                    guard let data = snapshot?.data() else {
                        self.hasSubscriptionBinding = false
                        self.hasMatchingSubscriptionBinding = false
                        self.updateProStatus()
                        return
                    }

                    let binding = SubscriptionBinding(
                        uid: data["uid"] as? String ?? "",
                        productId: data["productId"] as? String ?? "",
                        expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
                    )
                    self.applyBinding(binding, currentUID: uid)
                    self.updateProStatus()
                }
            }

        session.track(subscriptionListener)
    }

    private func setUser(_ uid: String?) {
        if uid != currentUID {
            stopEntitlementListeners()
            stopSubscriptionListener()
            currentUID = uid
            currentBindingID = nil
        }

        guard let uid else {
            resetStoreKitStateForSignedOutUser()
            return
        }

        startEntitlementListeners()
        Task { await refreshEntitlementsIfNeeded() }
    }

    private func resetStoreKitStateForSignedOutUser() {
        hasActiveStoreKitEntitlement = false
        hasSubscriptionBinding = false
        hasMatchingSubscriptionBinding = false
        hasRefreshedEntitlementsThisSession = false
        activeProductID = nil
        environment = nil
        statusMessage = nil
        lastError = nil
        shouldShowPaywall = false
        isPro = false
        currentBindingID = nil
    }

    nonisolated private func debugLog(_ items: Any...) {
        #if DEBUG
        print(items.map { String(describing: $0) }.joined(separator: " "))
        #endif
    }

    private func logStoreKitContext() {
        let bundleID = Bundle.main.bundleIdentifier ?? "(missing bundle identifier)"
        let storeKitResourcePath = Bundle.main.url(forResource: "EstimatorPro", withExtension: "storekit")?.path ?? "(no StoreKit config bundled)"
        let storeKitEnvPath = ProcessInfo.processInfo.environment["SIMULATOR_MAIN_STOREKIT_CONFIG"] ??
            ProcessInfo.processInfo.environment["STOREKIT_CONFIG"] ??
            "(StoreKit config env not set)"
        let simulatorName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "(not running in simulator)"
        let runningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] ?? "0"

        debugLog("[StoreKit] Bundle ID:", bundleID)
        debugLog("[StoreKit] Product IDs:", Self.productIDs)
        debugLog("[StoreKit] StoreKit config resource:", storeKitResourcePath)
        debugLog("[StoreKit] StoreKit config env:", storeKitEnvPath)
        debugLog("[StoreKit] Simulator device:", simulatorName)
        debugLog("[StoreKit] Xcode previews:", runningForPreviews)
    }

    private func logProductFetchDebug(requestedIDs: [String], returnedIDs: [String]) async {
        let bundleID = Bundle.main.bundleIdentifier ?? "(missing bundle identifier)"
        let entitlement = await activeSubscriptionEntitlement()

        debugLog("[StoreKit] Debug Bundle ID:", bundleID)
        debugLog("[StoreKit] Debug Requested IDs:", requestedIDs)
        debugLog("[StoreKit] Debug Returned IDs:", returnedIDs)
        debugLog("[StoreKit] Debug Active Entitlement:", entitlement?.productID ?? "none")
    }

    private func logEmptyProductsContext() {
        let environment = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            ? "Xcode Previews"
            : (ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil ? "Device" : "Simulator")
        debugLog("[StoreKit] No products returned. Likely causes: incorrect product IDs, bundle ID mismatch, products not approved/cleared, StoreKit configuration not selected, or App Store Connect not reachable.")
        debugLog("[StoreKit] Current environment:", environment)
    }

    private func logFirestoreError(_ error: Error, context: String, uid: String?) {
        let nsError = error as NSError
        debugLog("[Firestore] \(context) failed:", nsError.localizedDescription, "uid:", uid ?? "nil", "code:", nsError.code, "domain:", nsError.domain)
        if let firestoreCode = FirestoreErrorCode.Code(rawValue: nsError.code), firestoreCode == .permissionDenied {
            debugLog("[Firestore] Permission denied for \(context) uid:", uid ?? "nil")
        }
    }

    private func clearAuthState() {
        isLoading = false
        products = []
        lastError = nil
        statusMessage = nil
        setProductState(.idle)
        activeProductID = nil
        environment = nil
        shouldShowPaywall = false
        isPro = false
        hasActiveStoreKitEntitlement = false
        hasSubscriptionBinding = false
        hasMatchingSubscriptionBinding = false
        hasRefreshedEntitlementsThisSession = false
        currentBindingID = nil
    }

    func clear() {
        clearAuthState()
        stopEntitlementListeners()
        stopSubscriptionListener()
        currentUID = nil
    }
}
