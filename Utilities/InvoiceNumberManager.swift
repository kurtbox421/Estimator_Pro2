import Foundation

@MainActor
final class InvoiceNumberManager {
    static let shared = InvoiceNumberManager()

    private let storageKey = "EstimatorPro_LastInvoiceNumber"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func generateInvoiceNumber() -> String {
        let lastUsedNumber = userDefaults.integer(forKey: storageKey)
        let nextNumber = lastUsedNumber + 1
        userDefaults.set(nextNumber, forKey: storageKey)
        return String(format: "%03d", nextNumber)
    }
}
