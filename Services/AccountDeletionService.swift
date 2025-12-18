import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AccountDeletionError: LocalizedError {
    case noUser

    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No signed in user found."
        }
    }
}

struct AccountDeletionService {
    private let db: Firestore
    private let auth: Auth

    init(db: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = db
        self.auth = auth
    }

    func deleteAccount() async throws {
        guard let user = auth.currentUser else { throw AccountDeletionError.noUser }
        let uid = user.uid

        try await deleteUserData(for: uid)
        try await user.delete()
        try? auth.signOut()
        clearLocalCaches()
    }

    private func deleteUserData(for uid: String) async throws {
        let userDocument = db.collection("users").document(uid)

        let collections: [CollectionReference] = [
            userDocument.collection("clients"),
            userDocument.collection("jobs"),
            userDocument.collection("invoices"),
            userDocument.collection("supplies"),
            userDocument.collection("materialPrices"),
            userDocument.collection("materials")
        ]

        for collection in collections {
            try await deleteCollection(collection)
        }

        try? await userDocument.collection("materialPreferences")
            .document("preferences")
            .delete()

        try? await userDocument.collection("company")
            .document("settings")
            .delete()

        try? await userDocument.delete()
    }

    private func deleteCollection(_ collection: CollectionReference) async throws {
        var lastDocument: DocumentSnapshot?

        while true {
            var query: Query = collection.limit(to: 500)
            if let lastDocument {
                query = query.start(afterDocument: lastDocument)
            }

            let snapshot = try await query.getDocuments()
            guard !snapshot.documents.isEmpty else { break }

            let batch = db.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()

            lastDocument = snapshot.documents.last
        }
    }

    private func clearLocalCaches() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
    }
}
