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
    var clientId: UUID?
    var clientName: String
    var amount: Double
    var status: InvoiceStatus
    var createdAt: Date
    var dueDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        clientId: UUID? = nil,
        clientName: String,
        amount: Double,
        status: InvoiceStatus,
        createdAt: Date = Date(),
        dueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.clientId = clientId
        self.clientName = clientName
        self.amount = amount
        self.status = status
        self.createdAt = createdAt
        self.dueDate = dueDate
    }

    init(from job: Job, clientName: String) {
        self.init(
            title: job.name,
            clientId: job.clientId,
            clientName: clientName,
            amount: job.total,
            status: .draft
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case clientId
        case clientName
        case amount
        case status
        case createdAt
        case dueDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
        clientName = try container.decode(String.self, forKey: .clientName)
        amount = try container.decode(Double.self, forKey: .amount)
        status = try container.decode(InvoiceStatus.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
    }
}
