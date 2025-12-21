import Foundation

struct SavedMaterial: Identifiable, Codable, Equatable {
    var id = UUID()
    var ownerID: String
    var isDefault: Bool
    var name: String
    var price: Double

    init(id: UUID = UUID(), ownerID: String = "", isDefault: Bool = false, name: String, price: Double) {
        self.id = id
        self.ownerID = ownerID
        self.isDefault = isDefault
        self.name = name
        self.price = price
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLossyUUIDIfPresent(forKey: .id) ?? UUID()
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        name = try container.decode(String.self, forKey: .name)
        price = try container.decode(Double.self, forKey: .price)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case isDefault
        case name
        case price
    }
}
