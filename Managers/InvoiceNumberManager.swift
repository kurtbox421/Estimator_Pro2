import Foundation

final class InvoiceNumberManager {
    static let shared = InvoiceNumberManager()

    private let defaultsKey = "lastInvoiceNumber"

    private init() {}

    func generateInvoiceNumber() -> String {
        let defaults = UserDefaults.standard
        let last = defaults.integer(forKey: defaultsKey)   // 0 if not set
        let next = last + 1
        defaults.set(next, forKey: defaultsKey)
        return String(format: "%03d", next)                // 001, 002, ...
    }
}
