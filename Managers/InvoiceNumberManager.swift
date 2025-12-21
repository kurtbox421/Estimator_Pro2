import Foundation
import FirebaseAuth

enum InvoiceNumberManager {
    private static func storageKey(for uid: String?) -> String {
        guard let uid else { return "lastInvoiceNumber_anonymous" }
        return "lastInvoiceNumber_\(uid)"
    }

    static func generateInvoiceNumber(uid: String? = Auth.auth().currentUser?.uid) -> String {
        let defaults = UserDefaults.standard
        let key = storageKey(for: uid)
        let last = defaults.integer(forKey: key)
        let next = last + 1
        defaults.set(next, forKey: key)
        return String(format: "%03d", next)
    }
}
