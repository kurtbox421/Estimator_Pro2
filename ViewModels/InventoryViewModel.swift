import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var supplies: [SupplyItem] = []
    @Published var transactionsBySupply: [String: [InventoryTransaction]] = [:]
    @Published var errorMessage: String?

    private let db: Firestore
    private var listener: ListenerRegistration?
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var currentUserID: String?
    private var resetToken: UUID?

    init(database: Firestore = Firestore.firestore(), session: SessionManager) {
        self.db = database
        self.session = session
        resetToken = session.registerResetHandler { [weak self] in
            self?.clear()
        }
        session.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                self?.setUser(uid)
            }
            .store(in: &cancellables)
        setUser(session.uid)
    }

    deinit {
        listener?.remove()
        if let resetToken {
            session.unregisterResetHandler(resetToken)
        }
    }

    // MARK: - Auth

    private func setUser(_ uid: String?) {
        listener?.remove()
        currentUserID = uid
        supplies = []
        transactionsBySupply = [:]
        errorMessage = nil

        guard let uid else { return }

        let path = "users/\(uid)/supplies"
        print("[Data] InventoryViewModel uid=\(uid) path=\(path) action=listen")

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

        session.track(listener)
    }

    // MARK: - CRUD

    func upsertSupply(_ supply: SupplyItem) {
        guard let uid = currentUserID else { return }

        var supplyToSave = supply
        supplyToSave.ownerUserId = uid
        supplyToSave.updatedAt = Date()
        if supplyToSave.id == nil { supplyToSave.id = UUID().uuidString }
        if supplyToSave.createdAt > supplyToSave.updatedAt { supplyToSave.createdAt = Date() }

        do {
            let path = "users/\(uid)/supplies/\(supplyToSave.id ?? "")"
            print("[Data] InventoryViewModel uid=\(uid) path=\(path) action=write")
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
        guard let uid = currentUserID else { return }

        let path = "users/\(uid)/supplies/\(supplyId)/transactions"
        print("[Data] InventoryViewModel uid=\(uid) path=\(path) action=fetch")

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
        guard let uid = currentUserID else { throw InventoryError.unauthenticated }
        guard let supplyId = supply.id else { throw InventoryError.missingSupply }

        let path = "users/\(uid)/supplies/\(supplyId)"
        print("[Data] InventoryViewModel uid=\(uid) path=\(path) action=transaction")

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

        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(supplyRef)
                guard snapshot.exists else {
                    errorPointer?.pointee = NSError(domain: "Inventory", code: 0, userInfo: [NSLocalizedDescriptionKey: InventoryError.missingSupply.localizedDescription])
                    return nil
                }

                var currentSupply = try snapshot.data(as: SupplyItem.self)

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

    func clear() {
        listener?.remove()
        listener = nil
        currentUserID = nil
        supplies = []
        transactionsBySupply = [:]
        errorMessage = nil
    }
}
