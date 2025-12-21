import Foundation

struct LaborLine: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var hours: Double
    var rate: Double

    var total: Double { hours * rate }

    var hoursRateSummary: String {
        if hours > 0 || rate > 0 {
            let hoursString = Self.hoursFormatter.string(from: NSNumber(value: hours)) ?? String(hours)
            let rateString = rate.formatted(.currency(code: "USD"))
            return "\(hoursString) × \(rateString)"
        } else {
            return "Hours × Rate"
        }
    }

    private static let hoursFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case hours
        case rate
    }

    init(
        id: UUID = UUID(),
        title: String = "Labor",
        hours: Double = 0,
        rate: Double = 0
    ) {
        self.id = id
        self.title = title
        self.hours = hours
        self.rate = rate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Labor"
        hours = try container.decodeLossyDouble(forKey: .hours)
        rate = try container.decodeLossyDouble(forKey: .rate)
    }
}
