//
//  Material.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation

struct Material: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: Double
    var unitCost: Double
    var productURL: URL?

    var total: Double {
        quantity * unitCost
    }

    var cost: Double {
        total
    }

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unitCost: Double,
        productURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitCost = unitCost
        self.productURL = productURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unitCost
        case productURL
    }
}

