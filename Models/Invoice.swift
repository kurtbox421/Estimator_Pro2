import Foundation

struct Invoice: Identifiable, Codable {
    enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
        case draft
        case sent
        case overdue

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .draft:   return "Draft"
            case .sent:    return "Sent"
            case .overdue: return "Overdue"
            }
        }
    }

    var id: UUID
    var invoiceNumber: String
    var title: String
    var clientID: UUID?
    var clientName: String
    var materials: [Material]
    var status: InvoiceStatus
    var dueDate: Date?
    var ownerID: String

    var amount: Double {
        materials.reduce(into: 0) { $0 += $1.total }
    }

    // MARK: - Designated init

    init(
        id: UUID = UUID(),
        ownerID: String = "",
        invoiceNumber: String? = nil,
        title: String,
        clientID: UUID? = nil,
        clientName: String,
        materials: [Material] = [],
        status: InvoiceStatus,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.invoiceNumber = invoiceNumber
            ?? InvoiceNumberManager.shared.generateInvoiceNumber()
        self.title = title
        self.clientID = clientID
        self.clientName = clientName
        self.materials = materials
        self.status = status
        self.dueDate = dueDate
    }

    // MARK: - Convenience init from Job

    init(from job: Job, clientName: String, ownerID: String = "") {
        self.init(
            ownerID: ownerID,
            title: job.name,
            clientID: job.clientId,
            clientName: clientName,
            materials: job.materials,
            status: .draft
        )
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case invoiceNumber
        case title
        case clientID
        case clientName
        case materials
        case status
        case dueDate
        case ownerID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedId = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let decodedInvoiceNumber = try container.decodeIfPresent(String.self, forKey: .invoiceNumber)

        self.id = decodedId
        self.invoiceNumber = decodedInvoiceNumber
            ?? InvoiceNumberManager.shared.generateInvoiceNumber()
        self.title = try container.decode(String.self, forKey: .title)
        self.clientID = try container.decodeIfPresent(UUID.self, forKey: .clientID)
        self.clientName = try container.decode(String.self, forKey: .clientName)
        self.materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        self.status = try container.decode(InvoiceStatus.self, forKey: .status)
        self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        self.ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
    }
}
