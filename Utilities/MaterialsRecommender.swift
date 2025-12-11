import Foundation

enum MaterialJobType: CaseIterable, Identifiable {
    case interiorWallBuild
    case lvpFlooring
    case paintRoom
    case basicBathroomRemodel
    case exteriorPaint
    case tileBacksplash
    case deckBuild
    case roofShingleReplacement

    var id: Self { self }

    var displayName: String {
        switch self {
        case .interiorWallBuild:    return "Interior Wall Build"
        case .lvpFlooring:          return "LVP Flooring"
        case .paintRoom:            return "Paint Room"
        case .basicBathroomRemodel: return "Basic Bathroom Remodel"
        case .exteriorPaint:        return "Exterior Paint"
        case .tileBacksplash:       return "Tile Backsplash"
        case .deckBuild:            return "Deck Build"
        case .roofShingleReplacement: return "Roof Shingle Replacement"
        }
    }
}

struct JobContext {
    let jobType: MaterialJobType

    // Dimensions (interpret based on job type)
    let lengthFeet: Double?
    let secondaryFeet: Double?   // height for walls, width for floors, etc.

    // Extra fields for smarter logic (use sensible defaults if nil)
    let heightFeet: Double?      // optional override for wall height
    let areaSqFt: Double?        // optional direct area if already known

    let doorCount: Int
    let windowCount: Int

    let coats: Int               // for paint jobs
    let includesCeiling: Bool

    let wasteFactor: Double      // 0.1 = 10% for flooring etc.

    let notes: String?
}

struct MaterialRecommendation: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String            // "gallon", "sheet", "sq ft", "lf", etc.
    let category: String        // "Paint", "Drywall", "Flooring", "Prep", etc.
    let notes: String?
    var estimatedUnitCost: Double? = nil
}

private struct ResolvedGeneratorMaterial {
    let name: String
    let pricingUnit: String
    let coverageQuantity: Double?
    let coverageUnit: String?
    let notes: String?
    let estimatedUnitCost: Double?
}

enum GeneratorMaterialKey: String {
    case lvpFlooring = "lvp-floor-7x48"
    case foamUnderlayment = "underlayment-foam"
    case shoeMoulding = "trim-base-35"
}

struct MaterialsRecommender {

    let catalog: MaterialsCatalogStore

    func recommendMaterials(for context: JobContext) -> [MaterialRecommendation] {
        switch context.jobType {
        case .paintRoom:
            return recommendInteriorPaint(for: context)
        case .lvpFlooring:
            return recommendFlooring(for: context)
        case .interiorWallBuild:
            return recommendDrywall(for: context)
        case .basicBathroomRemodel:
            let paint = recommendInteriorPaint(for: context)
            let floor = recommendFlooring(for: context)
            return paint + floor
        case .exteriorPaint:
            return recommendExteriorPaint(for: context)
        case .tileBacksplash:
            return recommendTileBacksplash(for: context)
        case .deckBuild:
            return recommendDeck(for: context)
        case .roofShingleReplacement:
            return recommendRoofing(for: context)
        }
    }

    // MARK: - Helpers

    private func recommendInteriorPaint(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let width = ctx.secondaryFeet ?? 0
        let height = ctx.heightFeet ?? 8

        let perimeter = 2 * (length + width)
        var wallArea = perimeter * height
        wallArea -= Double(ctx.doorCount) * 21.0
        wallArea -= Double(ctx.windowCount) * 15.0
        wallArea = max(0, wallArea)

        let ceilingArea: Double
        if ctx.includesCeiling {
            ceilingArea = length * width
        } else {
            ceilingArea = 0
        }

        let totalArea = wallArea + ceilingArea
        let coats = max(ctx.coats, 1)

        let rawGallons = (totalArea * Double(coats)) / 350.0
        let gallonsWithWaste = rawGallons * 1.1
        let roundedGallons = max(1.0, (gallonsWithWaste * 2).rounded(.up) / 2)

        var recommendations: [MaterialRecommendation] = [
            MaterialRecommendation(
                name: "Interior Wall Paint (Eggshell, 1 gal)",
                quantity: roundedGallons,
                unit: "gallon",
                category: "Paint",
                notes: "Approx. \(Int(totalArea)) sq ft, \(coats) coat(s); ~350 sq ft/gal"
            )
        ]

        if coats >= 2 {
            let primerGallons = max(1.0, ((rawGallons * 1.05) * 2).rounded(.up) / 2)
            recommendations.append(
                MaterialRecommendation(
                    name: "Primer (1 gal)",
                    quantity: primerGallons,
                    unit: "gallon",
                    category: "Paint",
                    notes: "Coverage for ~\(Int(totalArea)) sq ft at ~350 sq ft/gal"
                )
            )
        }

        let caulkTubes = max(1.0, (perimeter / 30).rounded(.up))
        let tapeRolls = max(1.0, (perimeter / 60).rounded(.up))
        let rollerCovers = max(2.0, Double(coats) + 1).rounded(.up)

        recommendations.append(contentsOf: [
            MaterialRecommendation(
                name: "Paintable caulk",
                quantity: caulkTubes,
                unit: "tube",
                category: "Prep",
                notes: nil
            ),
            MaterialRecommendation(
                name: "Painter's tape",
                quantity: tapeRolls,
                unit: "roll",
                category: "Prep",
                notes: nil
            ),
            MaterialRecommendation(
                name: "Roller covers",
                quantity: rollerCovers,
                unit: "piece",
                category: "Paint",
                notes: "Includes extras for cutting in"
            )
        ])

        return recommendations
    }

    private func recommendDrywall(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let height = ctx.secondaryFeet ?? ctx.heightFeet ?? 8

        var area = length * height
        area *= 1.1 // 10% waste

        let sheetCount = (area / 32.0).rounded(.up)
        let screws = (sheetCount * 50).rounded(.up)
        let tapeRolls = max(1.0, (area / 500).rounded(.up))
        let mudBuckets = max(1.0, (area / 250).rounded(.up))
        let cornerLF = length * 0.5
        let beadSticks = cornerLF > 0 ? (cornerLF / 8).rounded(.up) : 0

        var recommendations: [MaterialRecommendation] = [
            MaterialRecommendation(
                name: "1/2\" drywall – 4×8",
                quantity: sheetCount,
                unit: "sheet",
                category: "Drywall",
                notes: nil
            ),
            MaterialRecommendation(
                name: "Drywall screws",
                quantity: screws,
                unit: "each",
                category: "Fasteners",
                notes: "~50 per sheet"
            ),
            MaterialRecommendation(
                name: "Joint tape",
                quantity: tapeRolls,
                unit: "roll",
                category: "Drywall",
                notes: "1 roll per ~500 sq ft"
            ),
            MaterialRecommendation(
                name: "Joint compound",
                quantity: mudBuckets,
                unit: "bucket",
                category: "Drywall",
                notes: "1 bucket per ~250 sq ft"
            )
        ]

        if beadSticks > 0 {
            recommendations.append(
                MaterialRecommendation(
                    name: "Corner bead",
                    quantity: beadSticks,
                    unit: "stick",
                    category: "Drywall",
                    notes: "Estimated from wall length"
                )
            )
        }

        return recommendations
    }

    private func recommendFlooring(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let width = ctx.secondaryFeet ?? 0

        let baseArea = ctx.areaSqFt ?? (length * width)
        let waste = ctx.wasteFactor > 0 ? ctx.wasteFactor : 0.1
        let totalArea = baseArea * (1 + waste)

        let flooringQty = totalArea.rounded(.up)
        let underlaymentRolls = (totalArea / 100).rounded(.up)
        let perimeter = 2 * (length + width)
        let mouldingLF = perimeter.rounded(.up)

        let flooringMaterial = resolveMaterial(
            key: .lvpFlooring,
            fallbackName: "LVP Flooring 7\"x48\" Planks",
            fallbackUnit: "sq ft",
            category: .flooring,
            notes: "Includes \(Int(waste * 100))% waste; ~30 sq ft per box",
            preferredUnits: ["box"],
            nameKeywords: ["floor"]
        )

        let underlayment = resolveMaterial(
            key: .foamUnderlayment,
            fallbackName: "Foam Underlayment (100 sq ft roll)",
            fallbackUnit: "roll",
            category: .flooring,
            notes: "100 sq ft per roll",
            preferredUnits: ["roll"],
            nameKeywords: ["underlayment"]
        )

        let moulding = resolveMaterial(
            key: .shoeMoulding,
            fallbackName: "Shoe moulding / quarter round",
            fallbackUnit: "lf",
            category: .trimFinish,
            notes: "Perimeter coverage",
            preferredUnits: ["lf"],
            nameKeywords: ["shoe", "quarter"]
        )

        let flooringCoverage = flooringMaterial.coverageQuantity ?? (flooringMaterial.pricingUnit.lowercased().contains("box") ? 30 : nil)
        let flooringNote = flooringCoverage.flatMap { coverage in
            let coverageUnit = flooringMaterial.coverageUnit ?? "sq ft"
            return "~\(Int(coverage)) \(coverageUnit) per \(flooringMaterial.pricingUnit)"
        }

        let flooringQuantity: Double
        let flooringUnit: String

        if let coverage = flooringCoverage { // convert to purchase units when we know coverage
            flooringQuantity = (flooringQty / coverage).rounded(.up)
            flooringUnit = flooringMaterial.pricingUnit
        } else {
            flooringQuantity = flooringQty
            flooringUnit = flooringMaterial.pricingUnit
        }

        return [
            MaterialRecommendation(
                name: flooringMaterial.name,
                quantity: flooringQuantity,
                unit: flooringUnit,
                category: MaterialCategory.flooring.displayName,
                notes: flooringMaterial.notes ?? flooringNote,
                estimatedUnitCost: flooringMaterial.estimatedUnitCost
            ),
            MaterialRecommendation(
                name: underlayment.name,
                quantity: underlaymentRolls,
                unit: underlayment.pricingUnit,
                category: MaterialCategory.flooring.displayName,
                notes: underlayment.notes,
                estimatedUnitCost: underlayment.estimatedUnitCost
            ),
            MaterialRecommendation(
                name: moulding.name,
                quantity: mouldingLF,
                unit: moulding.pricingUnit,
                category: MaterialCategory.trimFinish.displayName,
                notes: moulding.notes,
                estimatedUnitCost: moulding.estimatedUnitCost
            )
        ]
    }

    private func resolveMaterial(
        key: GeneratorMaterialKey,
        fallbackName: String,
        fallbackUnit: String,
        category: MaterialCategory,
        notes: String?,
        preferredUnits: [String],
        nameKeywords: [String]
    ) -> ResolvedGeneratorMaterial {
        let matchedMaterial = catalog.preferredMaterial(
            for: key.rawValue,
            category: category,
            nameKeywords: nameKeywords,
            preferredUnits: preferredUnits
        )

        let name = matchedMaterial?.name ?? fallbackName
        let unit = matchedMaterial?.unit ?? fallbackUnit
        let estimatedUnitCost = matchedMaterial.map { catalog.price(for: $0) }

        let autoCoverageNote: String?
        if let matchedMaterial,
           let coverage = matchedMaterial.coverageQuantity,
           let coverageUnit = matchedMaterial.coverageUnit {
            autoCoverageNote = "~\(Int(coverage)) \(coverageUnit) per \(matchedMaterial.unit)"
        } else {
            autoCoverageNote = nil
        }

        let resolvedNotes: String?
        if let notes, !notes.isEmpty {
            resolvedNotes = notes
        } else {
            resolvedNotes = autoCoverageNote
        }

        return ResolvedGeneratorMaterial(
            name: name,
            pricingUnit: unit,
            coverageQuantity: matchedMaterial?.coverageQuantity,
            coverageUnit: matchedMaterial?.coverageUnit,
            notes: resolvedNotes,
            estimatedUnitCost: estimatedUnitCost
        )
    }

    private func recommendExteriorPaint(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let width = ctx.secondaryFeet ?? 0
        let height = ctx.heightFeet ?? 9

        let perimeter = 2 * (length + width)
        let wallArea = max(0, perimeter * height)
        let coats = max(ctx.coats, 1)

        let gallons = max(1.0, ((wallArea * Double(coats)) / 300.0 * 1.15 * 2).rounded(.up) / 2)

        var recommendations: [MaterialRecommendation] = [
            MaterialRecommendation(
                name: "Exterior paint",
                quantity: gallons,
                unit: "gallon",
                category: "Paint",
                notes: "Approx. \(Int(wallArea)) sq ft, \(coats) coat(s)"
            ),
            MaterialRecommendation(
                name: "Exterior primer",
                quantity: max(1.0, (gallons * 0.75 * 2).rounded(.up) / 2),
                unit: "gallon",
                category: "Paint",
                notes: "Primer for weather-exposed surfaces"
            )
        ]

        let caulkTubes = max(1.0, (perimeter / 35).rounded(.up))
        let tapeRolls = max(1.0, (perimeter / 70).rounded(.up))

        recommendations.append(contentsOf: [
            MaterialRecommendation(
                name: "Exterior caulk",
                quantity: caulkTubes,
                unit: "tube",
                category: "Prep",
                notes: nil
            ),
            MaterialRecommendation(
                name: "Painter's tape",
                quantity: tapeRolls,
                unit: "roll",
                category: "Prep",
                notes: nil
            )
        ])

        return recommendations
    }

    private func recommendTileBacksplash(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let height = ctx.secondaryFeet ?? 2.5
        let area = max(0, length * height) * 1.1

        let thinsetBags = max(1.0, (area / 60).rounded(.up))
        let groutBags = max(1.0, (area / 40).rounded(.up))
        let edgeTrim = max(0, length).rounded(.up)

        return [
            MaterialRecommendation(
                name: "Tile",
                quantity: area.rounded(.up),
                unit: "sq ft",
                category: "Tile",
                notes: "Includes 10% overage"
            ),
            MaterialRecommendation(
                name: "Thinset mortar",
                quantity: thinsetBags,
                unit: "bag",
                category: "Adhesive",
                notes: "Approx. 60 sq ft coverage per bag"
            ),
            MaterialRecommendation(
                name: "Grout",
                quantity: groutBags,
                unit: "bag",
                category: "Finish",
                notes: "Approx. 40 sq ft coverage per bag"
            ),
            MaterialRecommendation(
                name: "Tile edge/trim",
                quantity: edgeTrim,
                unit: "lf",
                category: "Trim",
                notes: "Linear feet along exposed edges"
            )
        ]
    }

    private func recommendDeck(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let width = ctx.secondaryFeet ?? 0
        let area = max(0, length * width)
        let deckArea = area * 1.1
        let perimeter = 2 * (length + width)

        return [
            MaterialRecommendation(
                name: "Decking boards",
                quantity: deckArea.rounded(.up),
                unit: "sq ft",
                category: "Lumber",
                notes: "Includes 10% waste"
            ),
            MaterialRecommendation(
                name: "Joist hangers & fasteners",
                quantity: max(1.0, (perimeter / 4).rounded(.up)),
                unit: "each",
                category: "Hardware",
                notes: "Estimate based on perimeter framing"
            ),
            MaterialRecommendation(
                name: "Deck screws",
                quantity: max(1.0, (deckArea * 15 / 1_000).rounded(.up) * 1_000),
                unit: "pcs",
                category: "Fasteners",
                notes: "~15 screws per sq ft"
            ),
            MaterialRecommendation(
                name: "Railing materials",
                quantity: perimeter.rounded(.up),
                unit: "lf",
                category: "Railing",
                notes: "Linear feet of railing"
            )
        ]
    }

    private func recommendRoofing(for ctx: JobContext) -> [MaterialRecommendation] {
        let length = ctx.lengthFeet ?? 0
        let width = ctx.secondaryFeet ?? 0
        let baseArea = max(0, length * width)
        let totalArea = baseArea * 1.15

        let bundles = max(1.0, (totalArea / 33.3).rounded(.up))
        let underlayment = max(1.0, (totalArea / 200).rounded(.up))
        let ridgeVent = max(1.0, (length + width).rounded(.up))

        return [
            MaterialRecommendation(
                name: "Architectural shingles",
                quantity: bundles,
                unit: "bundle",
                category: "Roofing",
                notes: "Includes 15% waste"
            ),
            MaterialRecommendation(
                name: "Roofing underlayment",
                quantity: underlayment,
                unit: "roll",
                category: "Roofing",
                notes: "~200 sq ft per roll"
            ),
            MaterialRecommendation(
                name: "Roofing nails",
                quantity: max(1.0, (bundles * 320).rounded(.up)),
                unit: "pcs",
                category: "Fasteners",
                notes: "Approx. 320 nails per bundle"
            ),
            MaterialRecommendation(
                name: "Ridge vent & cap shingles",
                quantity: ridgeVent,
                unit: "lf",
                category: "Ventilation",
                notes: "Linear footage along ridges"
            )
        ]
    }
}
