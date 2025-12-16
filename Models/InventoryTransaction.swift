import Foundation
import FirebaseFirestoreSwift

struct InventoryTransaction: Identifiable, Codable, Hashable {
    enum TransactionType: String, Codable {
        case restock
        case use
        case adjustment
    }

    @DocumentID var id: String?
    var ownerUserId: String
    var supplyId: String
    var qtyChange: Double
    var type: TransactionType
    var note: String?
    var createdAt: Date

    init(
        id: String? = nil,
        ownerUserId: String,
        supplyId: String,
        qtyChange: Double,
        type: TransactionType,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.supplyId = supplyId
        self.qtyChange = qtyChange
        self.type = type
        self.note = note
        self.createdAt = createdAt
    }

    var stableId: String {
        id ?? "local-\(createdAt.timeIntervalSince1970)-\(qtyChange)"
    }
}
