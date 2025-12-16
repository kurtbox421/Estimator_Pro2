import Foundation
import FirebaseFirestoreSwift

struct SupplyItem: Identifiable, Codable, Hashable {
    @DocumentID var id: UUID?
    var ownerUserId: String
    var name: String
    var unit: String
    var onHand: Double
    var lowStockThreshold: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID? = UUID(),
        ownerUserId: String = "",
        name: String = "",
        unit: String = "",
        onHand: Double = 0,
        lowStockThreshold: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.name = name
        self.unit = unit
        self.onHand = onHand
        self.lowStockThreshold = lowStockThreshold
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isLowStock: Bool {
        guard let lowStockThreshold else { return false }
        return onHand < lowStockThreshold
    }

    var displayName: String {
        name.isEmpty ? "Untitled" : name
    }
}
