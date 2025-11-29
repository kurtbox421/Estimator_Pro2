import Foundation

struct SavedMaterial: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var price: Double

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case price
    }
}
