import Foundation
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let productIDs = [
        "estimator_pro_monthly",
        "estimator_pro_yearly"
    ]

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

    func loadProducts() async {
        isLoading = true
        setProductState(.loading)
        defer { isLoading = false }
        lastError = nil

        do {
            let idSet = Set(Self.productIDs)
            print("[StoreKit] Requesting products:", Array(idSet))
            let fetched = try await Product.products(for: idSet)
            let fetchedIDs = fetched.map(\.id)
            print("[StoreKit] Retrieved product ids:", fetchedIDs)

            guard !fetched.isEmpty else {
                let message = "No products returned from the App Store. Please try again."
                print("[StoreKit] Product fetch returned empty list")
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
            print("[StoreKit] Sorted product identifiers:", sortedIDs)
            products = sorted
            setProductState(.loaded(sorted))
        } catch {
            print("[StoreKit] Failed to load products:", error.localizedDescription)
            lastError = error.localizedDescription
            setProductState(.failed(error.localizedDescription))
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            print("[StoreKit] Purchasing product:", product.id)
            let result = try await product.purchase()
            print("[StoreKit] Purchase result received for product \(product.id):", String(describing: result))
            switch result {
            case .success(let verification):
                print("[StoreKit] Purchase success for product:", product.id)
                await handle(transactionResult: verification)
                if case .verified = verification, isPro {
                    print("[StoreKit] Pro access granted. Dismissing paywall.")
                    shouldShowPaywall = false
                }
            case .userCancelled:
                print("[StoreKit] Purchase cancelled by user for product:", product.id)
            case .pending:
                print("[StoreKit] Purchase pending for product:", product.id)
                lastError = "Purchase is pending. Please check your App Store purchases."
            @unknown default:
                print("[StoreKit] Purchase returned unknown state for product:", product.id)
                lastError = "Unknown purchase result. Please try again."
            }
        } catch {
            print("[StoreKit] Purchase failed for product \(product.id):", error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        let hasProAccess = await hasActiveSubscription()
        setIsPro(hasProAccess)
    }

    func hasActiveSubscription() async -> Bool {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }

            if let expiration = transaction.expirationDate, expiration < Date() {
                continue
            }
            if transaction.revocationDate != nil {
                continue
            }

            return true
        }

        return false
    }

    private func setIsPro(_ newValue: Bool) {
        isPro = newValue
        userDefaults.set(newValue, forKey: isProDefaultsKey)
    }

    func presentPaywall(after delay: TimeInterval = 0) {
        Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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
            print("[StoreKit] Verified transaction for product:", transaction.productID)
            await transaction.finish()
            await refreshEntitlements()
        case .unverified(_, let error):
            print("[StoreKit] Unverified transaction error:", error.localizedDescription)
            lastError = "Purchase verification failed: \(error.localizedDescription)"
        }
    }
}
