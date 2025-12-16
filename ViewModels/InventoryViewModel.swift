import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var supplies: [SupplyItem] = []
    @Published var transactionsBySupply: [String: [InventoryTransaction]] = [:]
    @Published var errorMessage: String?

    private let db: Firestore
    private let auth: Auth
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    init(database: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = database
        self.auth = auth
        configureAuthListener()
    }

    deinit {
        listener?.remove()
        if let authHandle { auth.removeStateDidChangeListener(authHandle) }
    }

    // MARK: - Auth

    private func configureAuthListener() {
        authHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.attachSupplyListener(for: user)
            }
        }

        Task { @MainActor in
            attachSupplyListener(for: auth.currentUser)
        }
    }

    private func attachSupplyListener(for user: User?) {
        listener?.remove()
        supplies = []

        guard let uid = user?.uid else { return }

        listener = db.collection("users")
            .document(uid)
            .collection("supplies")
            .order(by: "name", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = "Failed to load supplies: \(error.localizedDescription)"
                    return
                }

                let decoded: [SupplyItem] = snapshot?.documents.compactMap { document in
                    do {
                        return try document.data(as: SupplyItem.self)
                    } catch {
                        print("Failed to decode supply \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                } ?? []

                Task { @MainActor in
                    self.supplies = decoded
                }
            }
    }

    // MARK: - CRUD

    func upsertSupply(_ supply: SupplyItem) {
        guard let uid = auth.currentUser?.uid else { return }

        var supplyToSave = supply
        supplyToSave.ownerUserId = uid
        supplyToSave.updatedAt = Date()
        if supplyToSave.id == nil { supplyToSave.id = UUID().uuidString }
        if supplyToSave.createdAt > supplyToSave.updatedAt { supplyToSave.createdAt = Date() }

        do {
            try db.collection("users")
                .document(uid)
                .collection("supplies")
                .document(supplyToSave.id!)
                .setData(from: supplyToSave)
        } catch {
            errorMessage = "Unable to save supply: \(error.localizedDescription)"
        }
    }

    func fetchTransactions(for supplyId: String, limit: Int = 50) {
        guard let uid = auth.currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .collection("supplies")
            .document(supplyId)
            .collection("transactions")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to load history: \(error.localizedDescription)"
                    }
                    return
                }

                let decoded: [InventoryTransaction] = snapshot?.documents.compactMap { document in
                    do {
                        return try document.data(as: InventoryTransaction.self)
                    } catch {
                        print("Failed to decode transaction \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                } ?? []

                Task { @MainActor in
                    self.transactionsBySupply[supplyId] = decoded
                }
            }
    }

    func performRestock(for supply: SupplyItem, amount: Double, note: String? = nil) async throws {
        try await applyTransaction(for: supply, amount: amount, type: .restock, note: note)
    }

    func performUse(for supply: SupplyItem, amount: Double, note: String? = nil) async throws {
        try await applyTransaction(for: supply, amount: -abs(amount), type: .use, note: note)
    }

    // MARK: - Transaction logic

    enum InventoryError: LocalizedError {
        case unauthenticated
        case missingSupply
        case insufficientQuantity

        var errorDescription: String? {
            switch self {
            case .unauthenticated:
                return "You must be signed in to update inventory."
            case .missingSupply:
                return "Supply not found."
            case .insufficientQuantity:
                return "Not enough on hand to complete this action."
            }
        }
    }

    private func applyTransaction(
        for supply: SupplyItem,
        amount: Double,
        type: InventoryTransaction.TransactionType,
        note: String?
    ) async throws {
        guard let uid = auth.currentUser?.uid else { throw InventoryError.unauthenticated }
        guard let supplyId = supply.id else { throw InventoryError.missingSupply }

        let supplyRef = db.collection("users")
            .document(uid)
            .collection("supplies")
            .document(supplyId)

        let transactionId = UUID().uuidString
        let transactionRef = supplyRef
            .collection("transactions")
            .document(transactionId)

        let encoder = Firestore.Encoder()
        let now = Date()

        try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(supplyRef)
                guard var currentSupply = try snapshot.data(as: SupplyItem.self) else {
                    errorPointer?.pointee = NSError(domain: "Inventory", code: 0, userInfo: [NSLocalizedDescriptionKey: InventoryError.missingSupply.localizedDescription])
                    return nil
                }

                let updatedOnHand = currentSupply.onHand + amount
                if updatedOnHand < 0 {
                    errorPointer?.pointee = NSError(domain: "Inventory", code: 0, userInfo: [NSLocalizedDescriptionKey: InventoryError.insufficientQuantity.localizedDescription])
                    return nil
                }

                currentSupply.onHand = updatedOnHand
                currentSupply.updatedAt = now
                currentSupply.ownerUserId = uid

                let transactionRecord = InventoryTransaction(
                    id: transactionId,
                    ownerUserId: uid,
                    supplyId: supplyId,
                    qtyChange: amount,
                    type: type,
                    note: note,
                    createdAt: now
                )

                let supplyData = try encoder.encode(currentSupply)
                let transactionData = try encoder.encode(transactionRecord)

                transaction.setData(supplyData, forDocument: supplyRef)
                transaction.setData(transactionData, forDocument: transactionRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "Inventory", code: 0, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                return nil
            }

            return nil
        }
    }
}
