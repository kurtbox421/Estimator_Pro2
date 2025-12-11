import Foundation

/// Inputs used to compute quantities for various job types.
/// You won't always use every field for every job.
struct QuantityContext {
    // Walls
    var wallLengthFt: Double?      // single wall length
    var wallHeightFt: Double?      // wall height

    // Rooms / areas
    var roomFloorAreaSqFt: Double?
    var roomPerimeterFt: Double?

    // Decks / exterior surfaces
    var deckAreaSqFt: Double?
    var deckLengthFt: Double?
    var deckJoistSpanFt: Double?

    // Concrete
    var concreteVolumeCuFt: Double?

    // Openings (windows/doors)
    var openingCount: Int?

    // Bathrooms
    var bathroomCount: Int?

    // Tile areas
    var tileAreaSqFt: Double?
}

/// Result type that you can map to your JobMaterial model
struct GeneratedMaterial {
    let material: MaterialItem
    let quantity: Double
    let unitCost: Double
    var totalCost: Double { quantity * unitCost }
}

/// Quantity rule keys handled in Swift.
/// These match `quantityRuleKey` strings in the JSON.
enum QuantityRuleKey: String {
    case studs16OCWall         = "studs_16oc_wall"
    case platesWall            = "plates_wall"
    case sheetArea10Waste      = "sheet_area_10pct_waste"
    case sheetArea15Waste      = "sheet_area_15pct_waste"
    case flooring10Waste       = "flooring_10pct_waste"
    case rollCoverage100SqFt   = "roll_coverage_100sqft"
    case linearFt10Waste       = "linear_ft_10pct_waste"
    case linearFtExact         = "linear_ft_exact"
    case paintWalls            = "paint_walls"
    case caulkPerLinearFt      = "caulk_per_linear_ft"
    case adhesiveGeneric       = "adhesive_generic"
    case fastenersPerSheet     = "fasteners_per_sheet"
    case fastenersPerSqFtDeck  = "fasteners_per_sqft_deck"
    case insulationPerSqFt     = "insulation_per_sqft"
    case concretePerCuFt       = "concrete_per_cuft"
    case deckBoards16OC        = "deck_boards_16oc"
    case postsLinear           = "posts_linear"
    case joistHangersPerJoist  = "joist_hangers_per_joist"
    case membranePerSqFt       = "membrane_per_sqft"
    case thinsetPerSqFt        = "thinset_per_sqft"
    case groutPerSqFt          = "grout_per_sqft"
    case foamPerOpening        = "foam_per_opening"
    case shimsPerOpening       = "shims_per_opening"
    case outletsPerBath        = "outlets_per_bath"
    case pexPerBath            = "pex_per_bath"

    init?(from string: String?) {
        guard let string else { return nil }
        self.init(rawValue: string)
    }
}

struct MaterialQuantityEngine {

    func quantity(for material: MaterialItem, context: QuantityContext) -> Double {
        guard let key = QuantityRuleKey(from: material.quantityRuleKey) else {
            // If no rule, default to 1 so it at least shows up.
            return 1
        }

        let base = computeBaseQuantity(for: key, context: context)
        // Apply waste factor from material definition
        let withWaste = base * (1.0 + material.wasteFactor)
        let converted = applyCoverageConversion(withWaste, material: material)
        // Round to sensible units depending on the material
        return roundedQuantity(converted, unit: material.unit)
    }

    private func computeBaseQuantity(for key: QuantityRuleKey, context: QuantityContext) -> Double {
        switch key {

        case .studs16OCWall:
            // standard 16" OC stud calculation for one wall
            guard let length = context.wallLengthFt else { return 0 }
            // studs = (length / spacing) + 1
            let spacingFt = 16.0 / 12.0
            return (length / spacingFt).rounded(.up) + 1.0

        case .platesWall:
            // double top plate + bottom plate
            guard let length = context.wallLengthFt else { return 0 }
            let totalLinearFt = length * 3.0
            // each plate is a 16 ft board
            return (totalLinearFt / 16.0).rounded(.up)

        case .sheetArea10Waste, .sheetArea15Waste:
            guard let height = context.wallHeightFt,
                  let length = context.wallLengthFt else { return 0 }
            let area = height * length
            // 4x8 sheet = 32 sq ft
            let sheets = area / 32.0
            return sheets.rounded(.up)

        case .flooring10Waste:
            guard let area = context.roomFloorAreaSqFt else { return 0 }
            return area

        case .rollCoverage100SqFt:
            guard let area = context.roomFloorAreaSqFt else { return 0 }
            return (area / 100.0).rounded(.up)

        case .linearFt10Waste:
            guard let perimeter = context.roomPerimeterFt else { return 0 }
            return perimeter

        case .linearFtExact:
            guard let perimeter = context.roomPerimeterFt else { return 0 }
            return perimeter

        case .paintWalls:
            // Approx: 350 sq ft per gallon (1 coat).
            guard let perimeter = context.roomPerimeterFt,
                  let height = context.wallHeightFt else { return 0 }
            let wallArea = perimeter * height
            let coveragePerGallon: Double = 350.0
            // assume 2 coats
            let totalArea = wallArea * 2.0
            return (totalArea / coveragePerGallon).rounded(.up)

        case .caulkPerLinearFt:
            // Rough: 1 tube per 30 linear ft
            guard let perimeter = context.roomPerimeterFt else { return 0 }
            return (perimeter / 30.0).rounded(.up)

        case .adhesiveGeneric:
            // 1 per 100 sq ft or at least 1 if something exists
            if let area = context.roomFloorAreaSqFt, area > 0 {
                return max(1, (area / 100.0).rounded(.up))
            }
            if let length = context.wallLengthFt, length > 0 {
                return max(1, (length / 16.0).rounded(.up))
            }
            return 1

        case .fastenersPerSheet:
            // Assume 40 screws per sheet, 250 screws per lb
            guard let height = context.wallHeightFt,
                  let length = context.wallLengthFt else { return 0 }
            let area = height * length
            let sheets = (area / 32.0).rounded(.up)
            let screws = sheets * 40.0
            return (screws / 250.0).rounded(.up)

        case .fastenersPerSqFtDeck:
            // Assume 12 screws per sq ft, 150 per lb
            guard let area = context.deckAreaSqFt else { return 0 }
            let screws = area * 12.0
            return (screws / 150.0).rounded(.up)

        case .insulationPerSqFt:
            guard let height = context.wallHeightFt,
                  let length = context.wallLengthFt else { return 0 }
            let area = height * length
            // 1 bag roughly 40–50 sq ft, use 40 conservatively
            return (area / 40.0).rounded(.up)

        case .concretePerCuFt:
            guard let volume = context.concreteVolumeCuFt else { return 0 }
            // ~0.6 cu ft per 80 lb bag
            return (volume / 0.6).rounded(.up)

        case .deckBoards16OC:
            // assume deckAreaSqFt; 16 ft board ≈ 8 sq ft coverage
            guard let area = context.deckAreaSqFt else { return 0 }
            return (area / 8.0).rounded(.up)

        case .postsLinear:
            // 1 post every 8 ft along a run
            guard let length = context.deckLengthFt else { return 0 }
            return (length / 8.0).rounded(.up) + 1.0

        case .joistHangersPerJoist:
            guard let deckLength = context.deckLengthFt else { return 0 }
            let spacingFt = 16.0 / 12.0
            let joists = (deckLength / spacingFt).rounded(.up)
            return joists

        case .membranePerSqFt:
            guard let area = context.tileAreaSqFt else { return 0 }
            // assume roll covers 300 sq ft
            return (area / 300.0).rounded(.up)

        case .thinsetPerSqFt:
            guard let area = context.tileAreaSqFt else { return 0 }
            // ~50 sq ft per bag for floor tile
            return (area / 50.0).rounded(.up)

        case .groutPerSqFt:
            guard let area = context.tileAreaSqFt else { return 0 }
            // ~200 sq ft per 25 lb bag; use 150 for safety
            return (area / 150.0).rounded(.up)

        case .foamPerOpening:
            guard let openings = context.openingCount else { return 0 }
            return max(1, Double(openings))

        case .shimsPerOpening:
            guard let openings = context.openingCount else { return 0 }
            // 1 pack per 2 openings
            return max(1, (Double(openings) / 2.0).rounded(.up))

        case .outletsPerBath:
            guard let baths = context.bathroomCount else { return 0 }
            return Double(baths) * 2.0

        case .pexPerBath:
            guard let baths = context.bathroomCount else { return 0 }
            // ~80 ft per bath, 100 ft per coil
            let totalFt = Double(baths) * 80.0
            return (totalFt / 100.0).rounded(.up)
        }
    }

    private func roundedQuantity(_ value: Double, unit: String) -> Double {
        switch unit {
        case "each", "sheet", "bag", "box", "coil", "can", "tube", "roll":
            return max(1, value.rounded(.up))
        case "sqft", "linear_ft", "gallon":
            return (value * 100).rounded(.up) / 100.0
        default:
            return (value * 100).rounded(.up) / 100.0
        }
    }

    private func applyCoverageConversion(_ quantity: Double, material: MaterialItem) -> Double {
        guard let coverage = material.coverageQuantity,
              coverage > 0 else { return quantity }

        return (quantity / coverage).rounded(.up)
    }
}
