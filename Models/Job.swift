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
    var laborHours: Double
    var laborRate: Double
    var materials: [Material]
    var dateCreated: Date
    var clientId: UUID?

    var laborCost: Double { laborHours * laborRate }
    var materialCost: Double { materials.map { $0.cost }.reduce(0, +) }
    var total: Double { laborCost + materialCost }

    init(
        id: UUID = UUID(),
        ownerID: String = "",
        name: String,
        category: String,
        laborHours: Double,
        laborRate: Double,
        materials: [Material] = [],
        clientId: UUID? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.category = category
        self.laborHours = laborHours
        self.laborRate = laborRate
        self.materials = materials
        self.dateCreated = Date()
        self.clientId = clientId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case name
        case category
        case laborHours
        case laborRate
        case materials
        case dateCreated
        case clientId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        laborHours = try container.decode(Double.self, forKey: .laborHours)
        laborRate = try container.decode(Double.self, forKey: .laborRate)
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
    }
}

