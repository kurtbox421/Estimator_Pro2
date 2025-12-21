import Foundation
import FirebaseAuth

@MainActor
enum InvoiceNumberManager {
    private static func storageKey(for uid: String?) -> String {
        guard let uid else { return "EstimatorPro_LastInvoiceNumber_anonymous" }
        return "EstimatorPro_LastInvoiceNumber_\(uid)"
    }

    static func generateInvoiceNumber(uid: String? = Auth.auth().currentUser?.uid) -> String {
        let key = storageKey(for: uid)
        let lastUsedNumber = UserDefaults.standard.integer(forKey: key)
        let nextNumber = lastUsedNumber + 1
        UserDefaults.standard.set(nextNumber, forKey: key)
        return String(format: "%03d", nextNumber)
    }
}
