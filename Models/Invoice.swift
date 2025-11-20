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
    var clientID: UUID?
    var clientName: String
    var materials: [Material]
    var status: InvoiceStatus
    var dueDate: Date?

    var amount: Double { materials.reduce(0) { $0 + $1.total } }

    init(
        id: UUID = UUID(),
        title: String,
        clientID: UUID? = nil,
        clientName: String,
        materials: [Material] = [],
        status: InvoiceStatus,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.clientID = clientID
        self.clientName = clientName
        self.materials = materials
        self.status = status
        self.dueDate = dueDate
    }

    init(from job: Job, clientName: String) {
        self.init(
            title: job.name,
            clientID: job.clientId,
            clientName: clientName,
            materials: job.materials,
            status: .draft
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case clientID
        case clientName
        case materials
        case status
        case dueDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        clientName = try container.decode(String.self, forKey: .clientName)
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        status = try container.decode(InvoiceStatus.self, forKey: .status)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
    }
}
