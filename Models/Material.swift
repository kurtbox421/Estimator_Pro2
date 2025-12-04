//
//  Material.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation

struct Material: Identifiable, Codable {
    let id: UUID
    var ownerID: String
    var name: String
    var quantity: Double
    var unitCost: Double
    var productURL: URL?
    var unit: String?
    var notes: String?

    var total: Double {
        quantity * unitCost
    }

    var cost: Double {
        total
    }

    init(
        id: UUID = UUID(),
        ownerID: String,
        name: String,
        quantity: Double,
        unitCost: Double,
        productURL: URL? = nil,
        unit: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.quantity = quantity
        self.unitCost = unitCost
        self.productURL = productURL
        self.unit = unit
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unitCost
        case productURL
        case unit
        case notes
        case ownerID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? ""
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unitCost = try container.decode(Double.self, forKey: .unitCost)
        productURL = try container.decodeIfPresent(URL.self, forKey: .productURL)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

