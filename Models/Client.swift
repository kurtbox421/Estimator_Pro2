import Foundation

struct Client: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var company: String = ""
    var address: String = ""
    var phone: String = ""
    var email: String = ""
    var notes: String = ""
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
