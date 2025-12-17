import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let productIDs = [
        "estimator_pro_monthly",
        "estimator_pro_yearly"
    ]

    @Published var products: [Product] = []
    @Published var isPro: Bool
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var shouldShowPaywall: Bool = false

    private let userDefaults: UserDefaults
    private let isProDefaultsKey = "SubscriptionManager.isPro"
    private var updatesTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isPro = userDefaults.bool(forKey: isProDefaultsKey)

        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                await self.handle(transactionResult: result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let fetched = try await Product.products(for: Self.productIDs)
            let sorted = fetched.sorted { lhs, rhs in
                let lhsIndex = Self.productIDs.firstIndex(of: lhs.id) ?? .max
                let rhsIndex = Self.productIDs.firstIndex(of: rhs.id) ?? .max
                return lhsIndex < rhsIndex
            }
            products = sorted
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transactionResult: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
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
        var hasProAccess = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }

            if let expiration = transaction.expirationDate, expiration < Date() {
                continue
            }
            if transaction.revocationDate != nil {
                continue
            }

            hasProAccess = true
        }

        setIsPro(hasProAccess)
    }

    private func setIsPro(_ newValue: Bool) {
        isPro = newValue
        userDefaults.set(newValue, forKey: isProDefaultsKey)
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            await transaction.finish()
            await refreshEntitlements()
        case .unverified(_, let error):
            lastError = error.localizedDescription
        }
    }
}
