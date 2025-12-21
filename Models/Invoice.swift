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
    var ownerID: String
    var invoiceNumber: String
    var title: String
    var clientID: UUID?
    var clientName: String
    var materials: [Material]
    var laborLines: [LaborLine]
    var status: InvoiceStatus
    var dueDate: Date?

    var amount: Double {
        materials.reduce(into: 0) { $0 += $1.total } + laborSubtotal
    }

    var materialSubtotal: Double { materials.reduce(0) { $0 + $1.total } }
    var laborSubtotal: Double { laborLines.reduce(0) { $0 + $1.total } }

    // MARK: - Designated init

    init(
        id: UUID = UUID(),
        ownerID: String = "",
        invoiceNumber: String = InvoiceNumberManager.shared.generateInvoiceNumber(),
        title: String,
        clientID: UUID? = nil,
        clientName: String,
        materials: [Material] = [],
        laborLines: [LaborLine] = [],
        status: InvoiceStatus,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.invoiceNumber = invoiceNumber
        self.title = title
        self.clientID = clientID
        self.clientName = clientName
        self.materials = materials
        self.laborLines = laborLines
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
            laborLines: job.laborLines,
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
        case laborLines
        case status
        case dueDate
        case ownerID
        // Legacy
        case laborHours
        case laborRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedId = try container.decodeLossyUUIDIfPresent(forKey: .id) ?? UUID()
        let decodedInvoiceNumber = try container.decodeIfPresent(String.self, forKey: .invoiceNumber)

        self.id = decodedId
        self.invoiceNumber = decodedInvoiceNumber
            ?? InvoiceNumberManager.shared.generateInvoiceNumber()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Invoice"
        self.clientID = try container.decodeLossyUUIDIfPresent(forKey: .clientID)
        self.clientName = try container.decodeIfPresent(String.self, forKey: .clientName) ?? ""
        self.materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        if let decodedLaborLines = try container.decodeIfPresent([LaborLine].self, forKey: .laborLines) {
            self.laborLines = decodedLaborLines
        } else if let hours = try container.decodeIfPresent(Double.self, forKey: .laborHours),
                  let rate = try container.decodeIfPresent(Double.self, forKey: .laborRate),
                  hours > 0 || rate > 0 {
            self.laborLines = [LaborLine(id: UUID(), title: "Labor", hours: hours, rate: rate)]
        } else {
            self.laborLines = []
        }
        self.status = try container.decodeIfPresent(InvoiceStatus.self, forKey: .status) ?? .draft
        self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        self.ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(invoiceNumber, forKey: .invoiceNumber)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(clientID, forKey: .clientID)
        try container.encode(clientName, forKey: .clientName)
        try container.encode(materials, forKey: .materials)
        try container.encode(laborLines, forKey: .laborLines)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(ownerID, forKey: .ownerID)
    }
}
