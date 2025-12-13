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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        let decodedLaborLines = try container.decodeIfPresent([LaborLine].self, forKey: .laborLines) ?? []
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)

        if decodedLaborLines.isEmpty,
           let hours = try container.decodeIfPresent(Double.self, forKey: .laborHours),
           let rate = try container.decodeIfPresent(Double.self, forKey: .laborRate),
           hours > 0 || rate > 0 {
            laborLines = [LaborLine(id: UUID(), title: "Labor", hours: hours, rate: rate)]
        } else {
            laborLines = decodedLaborLines
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

