//
//  Job.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation

struct Job: Identifiable, Codable {
    let id: UUID
    var ownerID: String
    var name: String
    var category: String
    var laborLines: [LaborLine]
    var materials: [Material]
    var dateCreated: Date
    var clientId: UUID?

    var laborSubtotal: Double { laborLines.reduce(0) { $0 + $1.total } }
    var materialCost: Double { materials.map { $0.cost }.reduce(0, +) }
    var total: Double { laborSubtotal + materialCost }

    init(
        id: UUID = UUID(),
        ownerID: String = "",
        name: String,
        category: String,
        laborLines: [LaborLine] = [],
        materials: [Material] = [],
        clientId: UUID? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.category = category
        self.laborLines = laborLines
        self.materials = materials
        self.dateCreated = Date()
        self.clientId = clientId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case name
        case category
        case laborLines
        case materials
        case dateCreated
        case clientId
        // Legacy
        case laborHours
        case laborRate
    }

    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeLossyUUIDIfPresent(forKey: .id) ?? UUID()
            ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Job"
            category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
            let decodedLaborLines = (try? container.decodeIfPresent([LaborLine].self, forKey: .laborLines)) ?? []
            materials = (try? container.decodeIfPresent([Material].self, forKey: .materials)) ?? []
            dateCreated = try container.decodeLossyDateIfPresent(forKey: .dateCreated) ?? Date()
            clientId = try container.decodeLossyUUIDIfPresent(forKey: .clientId)

            if decodedLaborLines.isEmpty {
                let hours = try container.decodeLossyDoubleIfPresent(forKey: .laborHours) ?? 0
                let rate = try container.decodeLossyDoubleIfPresent(forKey: .laborRate) ?? 0
                if hours > 0 || rate > 0 {
                    laborLines = [LaborLine(title: "Labor", hours: hours, rate: rate)]
                } else {
                    laborLines = []
                }
            } else {
                laborLines = decodedLaborLines
            }
        } catch {
            Self.logDecodingError(error)
            throw error
        }
    }

    private static func logDecodingError(_ error: Error) {
        guard let decodingError = error as? DecodingError else {
            print("Decoding error: \(error)")
            return
        }

        func formatPath(_ path: [CodingKey]) -> String {
            path.map { $0.stringValue }.joined(separator: ".")
        }

        switch decodingError {
        case let .dataCorrupted(context):
            print("DecodingError.dataCorrupted at \(formatPath(context.codingPath)): \(context.debugDescription)")
        case let .keyNotFound(key, context):
            let path = formatPath(context.codingPath + [key])
            print("DecodingError.keyNotFound at \(path): \(context.debugDescription)")
        case let .typeMismatch(_, context):
            print("DecodingError.typeMismatch at \(formatPath(context.codingPath)): \(context.debugDescription)")
        case let .valueNotFound(_, context):
            print("DecodingError.valueNotFound at \(formatPath(context.codingPath)): \(context.debugDescription)")
        @unknown default:
            print("DecodingError.unknown: \(decodingError)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(laborLines, forKey: .laborLines)
        try container.encode(materials, forKey: .materials)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encodeIfPresent(clientId, forKey: .clientId)
    }
}
