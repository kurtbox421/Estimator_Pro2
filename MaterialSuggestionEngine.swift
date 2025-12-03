import Foundation

struct SuggestedMaterial: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let unitCost: Double

    var details: String {
        "\(String(format: "%.1f", quantity)) \(unit) @ \(unitCost.formatted(.currency(code: "USD")))"
    }

    var estimatedTotal: Double {
        quantity * unitCost
    }
}

enum MaterialSuggestionEngine {
    static func suggestMaterials(from description: String) -> [SuggestedMaterial] {
        let lowercasedDescription = description.lowercased()
        var materials: [SuggestedMaterial] = []

        if containsKeywords(["paint", "painting", "bedroom", "interior finish"], in: lowercasedDescription) {
            materials.append(contentsOf: paintingMaterials())
        }

        if containsKeywords(["drywall", "sheetrock", "basement", "framing"], in: lowercasedDescription) {
            materials.append(contentsOf: drywallMaterials())
        }

        if containsKeywords(["floor", "flooring", "lvp", "laminate", "hardwood", "tile"], in: lowercasedDescription) {
            materials.append(contentsOf: flooringMaterials())
        }

        if containsKeywords(["deck", "porch", "fence", "pergola", "exterior structure"], in: lowercasedDescription) {
            materials.append(contentsOf: exteriorStructureMaterials())
        }

        if containsKeywords(["roof", "shingle", "reroof"], in: lowercasedDescription) {
            materials.append(contentsOf: roofingMaterials())
        }

        if containsKeywords(["electrical", "outlet", "receptacle", "switch", "lighting"], in: lowercasedDescription) {
            materials.append(contentsOf: electricalMaterials())
        }

        if containsKeywords(["plumbing", "bath", "kitchen", "pipe", "water line"], in: lowercasedDescription) {
            materials.append(contentsOf: plumbingMaterials())
        }

        if containsKeywords(["concrete", "slab", "masonry", "sidewalk", "footing"], in: lowercasedDescription) {
            materials.append(contentsOf: concreteMaterials())
        }

        if !materials.isEmpty {
            materials.append(contentsOf: protectionAndCleanup())
        }

        if materials.isEmpty {
            materials.append(contentsOf: generalConstructionKit())
        }

        return mergeDuplicates(materials)
    }

    private static func paintingMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "Interior acrylic paint – eggshell", quantity: 4.0, unit: "gallons", unitCost: 42),
            SuggestedMaterial(name: "Stain-blocking primer", quantity: 2.0, unit: "gallons", unitCost: 32),
            SuggestedMaterial(name: "Painter's tape", quantity: 5.0, unit: "rolls", unitCost: 6.5),
            SuggestedMaterial(name: "Plastic sheeting", quantity: 3.0, unit: "rolls", unitCost: 22),
            SuggestedMaterial(name: "Canvas drop cloths", quantity: 3.0, unit: "pieces", unitCost: 18),
            SuggestedMaterial(name: "Rollers, frames, and trays", quantity: 2.0, unit: "kits", unitCost: 35),
            SuggestedMaterial(name: "Premium brush set", quantity: 1.0, unit: "set", unitCost: 28),
            SuggestedMaterial(name: "Roller covers – 3/8\" nap", quantity: 6.0, unit: "pieces", unitCost: 3.5),
            SuggestedMaterial(name: "Spackle and patch compound", quantity: 1.0, unit: "tub", unitCost: 9.5),
            SuggestedMaterial(name: "Sanding sponges – fine/medium", quantity: 4.0, unit: "pieces", unitCost: 3.25),
            SuggestedMaterial(name: "Paintable acrylic caulk", quantity: 6.0, unit: "tubes", unitCost: 5.25)
        ]
    }

    private static func drywallMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "1/2\" Drywall – 4x8 sheets", quantity: 40.0, unit: "sheets", unitCost: 15.5),
            SuggestedMaterial(name: "All-purpose joint compound", quantity: 7.0, unit: "buckets", unitCost: 23.5),
            SuggestedMaterial(name: "Paper joint tape", quantity: 10.0, unit: "rolls", unitCost: 4.5),
            SuggestedMaterial(name: "Metal corner bead", quantity: 18.0, unit: "pieces", unitCost: 5.0),
            SuggestedMaterial(name: "Drywall screws – 1-1/4\"", quantity: 20.0, unit: "lbs", unitCost: 7.5),
            SuggestedMaterial(name: "Drywall adhesive", quantity: 8.0, unit: "tubes", unitCost: 7.0),
            SuggestedMaterial(name: "Acoustical sealant", quantity: 6.0, unit: "tubes", unitCost: 8.5),
            SuggestedMaterial(name: "Pole sander sheets – 120 grit", quantity: 2.0, unit: "packs", unitCost: 9.0)
        ]
    }

    private static func flooringMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "Luxury vinyl plank flooring", quantity: 330.0, unit: "sq ft", unitCost: 2.85),
            SuggestedMaterial(name: "Underlayment with vapor barrier", quantity: 4.0, unit: "rolls", unitCost: 52),
            SuggestedMaterial(name: "Flooring transition strips", quantity: 6.0, unit: "pieces", unitCost: 18),
            SuggestedMaterial(name: "Quarter-round/shoe molding", quantity: 12.0, unit: "pieces", unitCost: 9.5),
            SuggestedMaterial(name: "Vapor barrier tape", quantity: 3.0, unit: "rolls", unitCost: 12),
            SuggestedMaterial(name: "Construction adhesive", quantity: 8.0, unit: "tubes", unitCost: 6.5),
            SuggestedMaterial(name: "Flooring spacers/shims", quantity: 2.0, unit: "bags", unitCost: 7.5),
            SuggestedMaterial(name: "Saw blades – fine tooth", quantity: 2.0, unit: "blades", unitCost: 18)
        ]
    }

    private static func exteriorStructureMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "Pressure-treated 6x6 posts – 10'", quantity: 8.0, unit: "pieces", unitCost: 42),
            SuggestedMaterial(name: "Pressure-treated 2x10 beams – 12'", quantity: 12.0, unit: "pieces", unitCost: 38),
            SuggestedMaterial(name: "Pressure-treated 2x8 joists – 12'", quantity: 22.0, unit: "pieces", unitCost: 26),
            SuggestedMaterial(name: "5/4x6 decking boards – 12'", quantity: 90.0, unit: "boards", unitCost: 18.25),
            SuggestedMaterial(name: "Joist hangers", quantity: 24.0, unit: "pieces", unitCost: 2.5),
            SuggestedMaterial(name: "Structural screws/ledger fasteners", quantity: 2.0, unit: "buckets", unitCost: 120),
            SuggestedMaterial(name: "Hidden deck fasteners", quantity: 6.0, unit: "boxes", unitCost: 75),
            SuggestedMaterial(name: "Galvanized post bases and caps", quantity: 8.0, unit: "sets", unitCost: 16),
            SuggestedMaterial(name: "Concrete mix for footings", quantity: 20.0, unit: "bags", unitCost: 6.5),
            SuggestedMaterial(name: "Flashing tape for ledgers", quantity: 4.0, unit: "rolls", unitCost: 32),
            SuggestedMaterial(name: "Railing hardware and balusters", quantity: 1.0, unit: "lot", unitCost: 350)
        ]
    }

    private static func roofingMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "Architectural shingles", quantity: 12.0, unit: "squares", unitCost: 110),
            SuggestedMaterial(name: "Synthetic felt underlayment", quantity: 12.0, unit: "rolls", unitCost: 25),
            SuggestedMaterial(name: "Ice & water shield", quantity: 6.0, unit: "rolls", unitCost: 55),
            SuggestedMaterial(name: "Drip edge flashing", quantity: 20.0, unit: "pieces", unitCost: 8.0),
            SuggestedMaterial(name: "Starter strip shingles", quantity: 12.0, unit: "bundles", unitCost: 32),
            SuggestedMaterial(name: "Roofing nails – coil", quantity: 50.0, unit: "lbs", unitCost: 1.35),
            SuggestedMaterial(name: "Ridge vent and caps", quantity: 80.0, unit: "ft", unitCost: 3.5),
            SuggestedMaterial(name: "Roof sealant/flash boots", quantity: 6.0, unit: "tubes", unitCost: 8.5)
        ]
    }

    private static func electricalMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "12/2 NM-B cable", quantity: 250.0, unit: "ft", unitCost: 0.82),
            SuggestedMaterial(name: "14/2 NM-B cable", quantity: 250.0, unit: "ft", unitCost: 0.65),
            SuggestedMaterial(name: "Single-gang electrical boxes", quantity: 20.0, unit: "pieces", unitCost: 2.5),
            SuggestedMaterial(name: "Duplex receptacles – tamper resistant", quantity: 20.0, unit: "pieces", unitCost: 2.2),
            SuggestedMaterial(name: "Single-pole switches", quantity: 8.0, unit: "pieces", unitCost: 3.0),
            SuggestedMaterial(name: "GFCI outlets", quantity: 2.0, unit: "pieces", unitCost: 18),
            SuggestedMaterial(name: "Cover plates – assorted", quantity: 20.0, unit: "pieces", unitCost: 1.35),
            SuggestedMaterial(name: "Wire nuts/connectors", quantity: 5.0, unit: "boxes", unitCost: 4.75),
            SuggestedMaterial(name: "Romex staples", quantity: 2.0, unit: "boxes", unitCost: 7.0),
            SuggestedMaterial(name: "Electrical tape", quantity: 4.0, unit: "rolls", unitCost: 4.5)
        ]
    }

    private static func plumbingMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "3/4\" PEX-A tubing", quantity: 200.0, unit: "ft", unitCost: 0.95),
            SuggestedMaterial(name: "1/2\" PEX-A tubing", quantity: 300.0, unit: "ft", unitCost: 0.65),
            SuggestedMaterial(name: "PEX elbows/tees/adapters", quantity: 30.0, unit: "pieces", unitCost: 4.0),
            SuggestedMaterial(name: "Ball valves – 3/4\"", quantity: 4.0, unit: "pieces", unitCost: 12.5),
            SuggestedMaterial(name: "Angle stops – 3/8\"", quantity: 10.0, unit: "pieces", unitCost: 6.0),
            SuggestedMaterial(name: "PEX crimp rings/sleeves", quantity: 2.0, unit: "boxes", unitCost: 18.0),
            SuggestedMaterial(name: "Pipe clamps/straps", quantity: 2.0, unit: "boxes", unitCost: 12.0),
            SuggestedMaterial(name: "Teflon tape", quantity: 6.0, unit: "rolls", unitCost: 1.5),
            SuggestedMaterial(name: "Plumber's putty/silicone", quantity: 2.0, unit: "tubs", unitCost: 5.5)
        ]
    }

    private static func concreteMaterials() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "Concrete mix – 60 lb bags", quantity: 45.0, unit: "bags", unitCost: 5.5),
            SuggestedMaterial(name: "3/4\" clean gravel base", quantity: 2.0, unit: "tons", unitCost: 45),
            SuggestedMaterial(name: "#4 rebar – 10' lengths", quantity: 40.0, unit: "pieces", unitCost: 8.25),
            SuggestedMaterial(name: "Form boards 2x4x10", quantity: 20.0, unit: "pieces", unitCost: 7.25),
            SuggestedMaterial(name: "Form stakes/fasteners", quantity: 30.0, unit: "pieces", unitCost: 2.5),
            SuggestedMaterial(name: "Tie wire – 16 gauge", quantity: 2.0, unit: "rolls", unitCost: 7.0),
            SuggestedMaterial(name: "Expansion joint material", quantity: 12.0, unit: "boards", unitCost: 9.0),
            SuggestedMaterial(name: "Concrete sealer/curing compound", quantity: 2.0, unit: "gallons", unitCost: 34)
        ]
    }

    private static func protectionAndCleanup() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "Floor protection board", quantity: 5.0, unit: "rolls", unitCost: 36),
            SuggestedMaterial(name: "Heavy-duty contractor bags", quantity: 2.0, unit: "boxes", unitCost: 18),
            SuggestedMaterial(name: "Shop towels and rags", quantity: 4.0, unit: "packs", unitCost: 6.5),
            SuggestedMaterial(name: "Construction debris dumpster – 10 yd", quantity: 1.0, unit: "rental", unitCost: 425)
        ]
    }

    private static func generalConstructionKit() -> [SuggestedMaterial] {
        [
            SuggestedMaterial(name: "General framing lumber and sheathing", quantity: 1.0, unit: "lot", unitCost: 650),
            SuggestedMaterial(name: "Screws, nails, and anchors assortment", quantity: 1.0, unit: "lot", unitCost: 185),
            SuggestedMaterial(name: "Construction adhesive and sealants", quantity: 1.0, unit: "lot", unitCost: 120),
            SuggestedMaterial(name: "Surface protection and masking", quantity: 1.0, unit: "lot", unitCost: 160),
            SuggestedMaterial(name: "Debris haul-off/dumpster", quantity: 1.0, unit: "rental", unitCost: 425)
        ]
    }

    private static func containsKeywords(_ keywords: [String], in text: String) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func mergeDuplicates(_ materials: [SuggestedMaterial]) -> [SuggestedMaterial] {
        var merged: [String: (quantity: Double, unit: String, unitCost: Double)] = [:]

        for material in materials {
            if var existing = merged[material.name] {
                existing.quantity += material.quantity
                merged[material.name] = existing
            } else {
                merged[material.name] = (material.quantity, material.unit, material.unitCost)
            }
        }

        return merged.map { key, value in
            SuggestedMaterial(name: key, quantity: value.quantity, unit: value.unit, unitCost: value.unitCost)
        }
        .sorted { $0.name < $1.name }
    }
}
