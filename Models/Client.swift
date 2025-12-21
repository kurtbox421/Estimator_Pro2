import Foundation

struct Client: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var ownerID: String = ""
    var name: String = ""
    var company: String = ""
    var address: String = ""
    var phone: String = ""
    var email: String = ""
    var notes: String = ""

    init(
        id: UUID = UUID(),
        ownerID: String = "",
        name: String = "",
        company: String = "",
        address: String = "",
        phone: String = "",
        email: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.company = company
        self.address = address
        self.phone = phone
        self.email = email
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case name
        case company
        case address
        case phone
        case email
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLossyUUIDIfPresent(forKey: .id) ?? UUID()
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

extension Client {
    static func jobSummary(for jobCount: Int) -> String {
        jobCount == 1 ? "1 job" : "\(jobCount) jobs"
    }

    var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
        let letters = parts.compactMap { $0.first }
        let initials = letters.map { String($0) }.joined()
        return initials.isEmpty ? "?" : initials.uppercased()
    }

    static let sampleData: [Client] = [
        Client(
            name: "Johnny Appleseed",
            company: "B&B Apple Company",
            address: "123 Honeycrisp Dr · Cupertino, CA",
            phone: "(234) 421-3860",
            email: "johnny@bbapple.co",
            notes: "Prefers afternoon calls"
        ),
        Client(
            name: "Maria Sanchez",
            company: "Sunrise Renovations",
            address: "88 Goldenrod Ave · Portland, OR",
            phone: "(503) 881-2244",
            email: "maria@sunrisebuilds.com",
            notes: "Repeat customer"
        )
    ]
}
