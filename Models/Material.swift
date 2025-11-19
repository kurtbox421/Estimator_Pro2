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

    var cost: Double {
        quantity * unitCost
    }

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unitCost: Double
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitCost = unitCost
    }
}

