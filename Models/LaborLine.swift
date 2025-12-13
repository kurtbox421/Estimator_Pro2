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
}
