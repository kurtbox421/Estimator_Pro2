import Foundation

enum MaterialJobType: CaseIterable, Identifiable {
    case interiorWallBuild
    case lvpFlooring
    case paintRoom
    case basicBathroomRemodel

    var id: Self { self }

    var displayName: String {
        switch self {
        case .interiorWallBuild:    return "Interior Wall Build"
        case .lvpFlooring:          return "LVP Flooring"
        case .paintRoom:            return "Paint Room"
        case .basicBathroomRemodel: return "Basic Bathroom Remodel"
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
}

struct MaterialsRecommender {

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
                name: "Interior wall paint",
                quantity: roundedGallons,
                unit: "gallon",
                category: "Paint",
                notes: "Approx. \(Int(totalArea)) sq ft, \(coats) coat(s)"
            )
        ]

        if coats >= 2 {
            let primerGallons = max(1.0, ((rawGallons * 1.05) * 2).rounded(.up) / 2)
            recommendations.append(
                MaterialRecommendation(
                    name: "Primer",
                    quantity: primerGallons,
                    unit: "gallon",
                    category: "Paint",
                    notes: "Coverage for ~\(Int(totalArea)) sq ft"
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

        return [
            MaterialRecommendation(
                name: "Flooring (e.g. LVP)",
                quantity: flooringQty,
                unit: "sq ft",
                category: "Flooring",
                notes: "Includes \(Int(waste * 100))% waste"
            ),
            MaterialRecommendation(
                name: "Underlayment",
                quantity: underlaymentRolls,
                unit: "roll",
                category: "Flooring",
                notes: "100 sq ft per roll"
            ),
            MaterialRecommendation(
                name: "Shoe moulding / quarter round",
                quantity: mouldingLF,
                unit: "lf",
                category: "Trim",
                notes: "Perimeter coverage"
            )
        ]
    }
}
