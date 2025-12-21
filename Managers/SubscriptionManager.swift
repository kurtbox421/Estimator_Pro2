import Foundation
import FirebaseAuth
import FirebaseFirestore
import StoreKit
import SwiftUI

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
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUID: String?

    init(database: Firestore = Firestore.firestore()) {
        self.db = database
        self.isPro = false
        self.activeProductID = nil
        self.environment = nil

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthStateChange(user)
            }
        }

        handleAuthStateChange(Auth.auth().currentUser)
    }

    deinit {
        stopEntitlementListeners()
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
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
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        statusMessage = "Processing purchase…"

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transactionResult: verification)
                if case .verified = verification {
                    await refreshEntitlements()
                    if isPro {
                        statusMessage = "Thanks for subscribing to Pro!"
                        shouldShowPaywall = false
                    }
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
        }
    }

    func restorePurchases() async {
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
        }

        await refreshEntitlements(showRestoreMessage: true)
    }

    func refreshEntitlements(showRestoreMessage: Bool = false) async {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            clearCachedProStatus()
            return
        }

        resetEntitlementState()

        let entitlement = await activeSubscriptionEntitlement()
        let entitlementActive = entitlement != nil
        let activeProductID = entitlement?.productID
        let environmentValue = entitlement.map { environmentString(for: $0) } ?? "unknown"
        let originalTransactionId = entitlement.map { String($0.originalID) }

        var isEntitled = false
        var bindingDenied = false

        if let entitlement,
           let originalTransactionId {
            do {
                isEntitled = try await bindSubscriptionIfNeeded(
                    uid: currentUID,
                    originalTransactionId: originalTransactionId,
                    productId: entitlement.productID,
                    environment: environmentValue
                )
                bindingDenied = !isEntitled
            } catch {
                debugLog("[Firestore] Failed to bind subscription:", error.localizedDescription)
                lastError = "Unable to verify subscription binding. Please try again."
                statusMessage = lastError
            }
        }

        if entitlementActive, bindingDenied {
            lastError = "subscription linked to another account"
            statusMessage = lastError
        }

        setIsPro(entitlementActive && isEntitled)
        setActiveProductID(activeProductID)
        setEnvironment(environmentValue)
        await updateUserEntitlement(
            uid: currentUID,
            isPro: entitlementActive && isEntitled,
            activeProductID: activeProductID,
            environment: environmentValue,
            originalTransactionId: originalTransactionId
        )

        if showRestoreMessage {
            if entitlementActive, let entitlement {
                statusMessage = isEntitled
                    ? "Restored Estimator Pro (\(entitlement.productID))."
                    : "subscription linked to another account"
            } else {
                statusMessage = "No purchases found to restore."
            }
        }
    }


    private func activeSubscriptionEntitlement() async -> StoreKit.Transaction? {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }

            if isTransactionActive(transaction) {
                return transaction
            }
        }

        for productID in Self.productIDs {
            guard let latest = try? await StoreKit.Transaction.latest(for: productID) else { continue }

            if case .verified(let transaction) = latest, isTransactionActive(transaction) {
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

    private func setIsPro(_ newValue: Bool) {
        isPro = newValue
    }

    private func setActiveProductID(_ newValue: String?) {
        activeProductID = newValue
    }

    private func setEnvironment(_ newValue: String?) {
        environment = newValue
    }

    private func clearCachedProStatus() {
        setIsPro(false)
        setActiveProductID(nil)
        setEnvironment(nil)
        statusMessage = nil
    }

    private func resetEntitlementState() {
        setIsPro(false)
        setActiveProductID(nil)
        setEnvironment(nil)
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
            await transaction.finish()
            await refreshEntitlements()
        case .unverified(_, let error):
            lastError = "Purchase verification failed: \(error.localizedDescription)"
        }
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

    private func updateUserEntitlement(
        uid: String,
        isPro: Bool,
        activeProductID: String?,
        environment: String,
        originalTransactionId: String?
    ) async {
        var data: [String: Any] = [
            "isPro": isPro,
            "updatedAt": FieldValue.serverTimestamp(),
            "environment": environment,
            "activeProductID": activeProductID ?? NSNull(),
            "originalTransactionId": originalTransactionId ?? NSNull()
        ]

        let docRef = db.collection("users")
            .document(uid)
            .collection("entitlements")
            .document("pro")

        do {
            try await docRef.setData(data, merge: true)
        } catch {
            self.debugLog("[Firestore] Failed to update entitlement:", error.localizedDescription)
        }
    }

    private func environmentString(for transaction: StoreKit.Transaction) -> String {
        switch transaction.environment {
        case .xcode:
            return "xcode"
        case .sandbox:
            return "sandbox"
        case .production:
            return "production"
        @unknown default:
            return "unknown"
        }
    }

    private func bindSubscriptionIfNeeded(
        uid: String,
        originalTransactionId: String,
        productId: String,
        environment: String
    ) async throws -> Bool {
        let docRef = db.collection("subscriptionBindings").document(originalTransactionId)

        return try await withCheckedThrowingContinuation { continuation in
            db.runTransaction({ transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(docRef)
                    if let data = snapshot.data(),
                       let boundUID = data["uid"] as? String {
                        if boundUID != uid {
                            return ["isEntitled": false]
                        }

                        transaction.updateData([
                            "productId": productId,
                            "environment": environment,
                            "updatedAt": FieldValue.serverTimestamp()
                        ], forDocument: docRef)
                        return ["isEntitled": true]
                    }

                    transaction.setData([
                        "uid": uid,
                        "productId": productId,
                        "environment": environment,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: docRef, merge: false)
                    return ["isEntitled": true]
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let isEntitled = (result as? [String: Any])?["isEntitled"] as? Bool ?? false
                continuation.resume(returning: isEntitled)
            })
        }
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
            isPro = false
            activeProductID = nil
            environment = nil
            shouldShowPaywall = false
        }
    }

    private func handleAuthStateChange(_ user: User?) {
        // Tie entitlement state to the auth user and clear it on logout to prevent cross-account bleed.
        let newUID = user?.uid
        if newUID != currentUID {
            stopEntitlementListeners()
            currentUID = newUID
        }

        guard newUID != nil else {
            return
        }

        startEntitlementListeners()
        Task {
            await refreshEntitlements()
        }
    }
}
