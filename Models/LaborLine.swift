import Foundation

struct LaborLine: Identifiable, Codable {
    var id: UUID
    var title: String
    var hours: Double
    var rate: Double

    var total: Double { hours * rate }
}
