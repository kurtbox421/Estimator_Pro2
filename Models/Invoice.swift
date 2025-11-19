import Foundation

struct Invoice: Identifiable, Codable {
    enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
        case draft
        case sent
        case overdue

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .draft: return "Draft"
            case .sent: return "Sent"
            case .overdue: return "Overdue"
            }
        }
    }

    var id: UUID
    var title: String
    var clientName: String
    var amount: Double
    var status: InvoiceStatus
    var dueDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        clientName: String,
        amount: Double,
        status: InvoiceStatus,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.clientName = clientName
        self.amount = amount
        self.status = status
        self.dueDate = dueDate
    }
}
