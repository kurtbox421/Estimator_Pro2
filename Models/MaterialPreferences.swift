import Foundation

struct MaterialPreferences: Identifiable, Codable {
    var id: String
    var ownerID: String
    var priceOverrides: [String: Double]
    var productURLOverrides: [String: URL]
    var removedMaterialIDs: [String]

    init(
        id: String,
        ownerID: String,
        priceOverrides: [String: Double] = [:],
        productURLOverrides: [String: URL] = [:],
        removedMaterialIDs: [String] = []
    ) {
        self.id = id
        self.ownerID = ownerID
        self.priceOverrides = priceOverrides
        self.productURLOverrides = productURLOverrides
        self.removedMaterialIDs = removedMaterialIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? id
        priceOverrides = try container.decodeIfPresent([String: Double].self, forKey: .priceOverrides) ?? [:]
        productURLOverrides = try container.decodeIfPresent([String: URL].self, forKey: .productURLOverrides) ?? [:]
        removedMaterialIDs = try container.decodeIfPresent([String].self, forKey: .removedMaterialIDs) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case priceOverrides
        case productURLOverrides
        case removedMaterialIDs
    }
}
