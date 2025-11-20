//
//  Job.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation

struct Job: Identifiable, Codable {
    let id: UUID
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
        name: String,
        category: String,
        laborHours: Double,
        laborRate: Double,
        materials: [Material] = [],
        clientId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.laborHours = laborHours
        self.laborRate = laborRate
        self.materials = materials
        self.dateCreated = Date()
        self.clientId = clientId
    }
}

