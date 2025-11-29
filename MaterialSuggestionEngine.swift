import Foundation

struct GeneratedMaterial: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let unitCost: Double

    var details: String {
        "\(quantity, specifier: \"%.1f\") \(unit) @ \(unitCost.formatted(.currency(code: \"USD\")))"
    }

    var estimatedTotal: Double {
        quantity * unitCost
    }
}

enum MaterialSuggestionEngine {
    static func suggestMaterials(from description: String) -> [GeneratedMaterial] {
        let lowercasedDescription = description.lowercased()
        var materials: [GeneratedMaterial] = []

        if lowercasedDescription.contains("drywall") || lowercasedDescription.contains("basement") {
            materials.append(contentsOf: [
                GeneratedMaterial(name: "1/2\" Drywall sheets", quantity: 20, unit: "sheets", unitCost: 15),
                GeneratedMaterial(name: "Joint compound", quantity: 5, unit: "buckets", unitCost: 25),
                GeneratedMaterial(name: "Drywall screws", quantity: 5, unit: "lbs", unitCost: 7)
            ])
        }

        if lowercasedDescription.contains("paint") || lowercasedDescription.contains("bedroom") {
            materials.append(contentsOf: [
                GeneratedMaterial(name: "Interior wall paint", quantity: 3, unit: "gallons", unitCost: 45),
                GeneratedMaterial(name: "Primer", quantity: 2, unit: "gallons", unitCost: 30),
                GeneratedMaterial(name: "Rollers & brushes", quantity: 1, unit: "kit", unitCost: 35)
            ])
        }

        if lowercasedDescription.contains("deck") || lowercasedDescription.contains("porch") {
            materials.append(contentsOf: [
                GeneratedMaterial(name: "Pressure-treated decking boards", quantity: 40, unit: "boards", unitCost: 18),
                GeneratedMaterial(name: "Deck screws", quantity: 10, unit: "lbs", unitCost: 9),
                GeneratedMaterial(name: "Post concrete mix", quantity: 8, unit: "bags", unitCost: 6)
            ])
        }

        if materials.isEmpty {
            materials.append(
                GeneratedMaterial(
                    name: "General construction materials",
                    quantity: 1,
                    unit: "lot",
                    unitCost: 250
                )
            )
        }

        return materials
    }
}
