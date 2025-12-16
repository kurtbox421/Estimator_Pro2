import Foundation
import FirebaseFirestoreSwift

struct InventoryTransaction: Identifiable, Codable, Hashable {
    enum TransactionType: String, Codable {
        case restock
        case use
        case adjustment
    }

    @DocumentID var id: UUID?
    var ownerUserId: String
    var supplyId: UUID
    var qtyChange: Double
    var type: TransactionType
    var note: String?
    var createdAt: Date

    init(
        id: UUID? = UUID(),
        ownerUserId: String,
        supplyId: UUID,
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
}
