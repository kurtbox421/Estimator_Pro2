import Foundation
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
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var statusMessage: String?
    @Published var shouldShowPaywall: Bool = false
    @Published var productState: ProductLoadState = .idle
    @Published private(set) var productStateChangeToken: Int = 0

    private let userDefaults: UserDefaults
    private let isProDefaultsKey = "SubscriptionManager.isPro"
    private var updatesTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isPro = userDefaults.bool(forKey: isProDefaultsKey)

        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in StoreKit.Transaction.updates {
                await self.handle(transactionResult: result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts(timeout: TimeInterval = 10) async {
        isLoading = true
        setProductState(.loading)
        defer { isLoading = false }
        lastError = nil
        statusMessage = nil

        do {
            let fetched = try await fetchProducts(within: timeout)
            let fetchedIDs = fetched.map(\.id)
            debugLog("[StoreKit] Retrieved product ids:", fetchedIDs)

            guard !fetched.isEmpty else {
                let message = "No products returned from the App Store. Please try again."
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
                if case .verified = verification, isPro {
                    statusMessage = "Thanks for subscribing to Pro!"
                    shouldShowPaywall = false
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

        await AppStore.sync()

        if let entitlement = await activeSubscriptionEntitlement() {
            setIsPro(true)
            statusMessage = "Restored Estimator Pro (\(entitlement.productID))."
        } else {
            setIsPro(false)
            statusMessage = "No purchases found to restore."
        }
    }

    func refreshEntitlements() async {
        let entitlement = await activeSubscriptionEntitlement()
        setIsPro(entitlement != nil)
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
        userDefaults.set(newValue, forKey: isProDefaultsKey)
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
        let ids = Set(Self.productIDs)
        let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
        let logger = debugLog

        return try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask {
                logger("[StoreKit] Requesting products:", Array(ids))
                return try await Product.products(for: ids)
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
}
