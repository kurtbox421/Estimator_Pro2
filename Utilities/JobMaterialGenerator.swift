import Foundation

enum JobType: String, CaseIterable, Identifiable {
    case interiorWall
    case lvpFloor
    case paintRoom
    case basicBathRemodel
    case deckSurfaceReplace
    case windowInstall

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .interiorWall:        return "Interior Wall Build"
        case .lvpFloor:            return "LVP Flooring"
        case .paintRoom:           return "Paint Room"
        case .basicBathRemodel:    return "Basic Bathroom Remodel"
        case .deckSurfaceReplace:  return "Deck Surface Replacement"
        case .windowInstall:       return "Window Install"
        }
    }

    var jobTag: MaterialJobTag {
        switch self {
        case .interiorWall: return .interiorWallBuild
        case .lvpFloor: return .lvpFlooring
        case .paintRoom: return .paintRoom
        case .basicBathRemodel: return .basicBathroomRemodel
        case .deckSurfaceReplace: return .deckSurfaceReplace
        case .windowInstall: return .windowInstall
        }
    }
}

/// Connects job types -> list of material IDs + provided context
struct JobMaterialGenerator {

    let catalog: MaterialsCatalogStore
    let engine = MaterialQuantityEngine()

    func generateMaterials(
        for jobType: JobType,
        context: QuantityContext
    ) -> [GeneratedMaterial] {
        let taggedMaterials = catalog.materials(for: jobType.jobTag)
        let fallbackMaterials = materialIDs(for: jobType).compactMap { catalog.material(withID: $0) }
        let materials = taggedMaterials.isEmpty ? fallbackMaterials : taggedMaterials

        return materials.compactMap { material in
            let qty = min(engine.quantity(for: material, context: context), maxRecommendedQuantity(for: material))
            guard qty > 0 else { return nil }
            return GeneratedMaterial(
                material: material,
                quantity: qty,
                unitCost: catalog.price(for: material)
            )
        }
    }

    private func maxRecommendedQuantity(for material: MaterialItem) -> Double {
        switch material.id {
        case "screws-drywall-125":
            return 5
        default:
            return .greatestFiniteMagnitude
        }
    }

    func allMaterialIDs() -> [String] {
        let taggedIDs = JobType.allCases.flatMap { jobType in
            catalog.materials(for: jobType.jobTag).map { $0.id }
        }

        let fallbackIDs = JobType.allCases.flatMap { materialIDs(for: $0) }
        let ids = (taggedIDs.isEmpty ? fallbackIDs : taggedIDs) + catalog.customMaterialIDs

        var uniqueOrderedIDs: [String] = []
        var seen: Set<String> = []

        for id in ids where seen.insert(id).inserted {
            uniqueOrderedIDs.append(id)
        }

        return uniqueOrderedIDs
    }

    private func materialIDs(for jobType: JobType) -> [String] {
        switch jobType {
        case .interiorWall:
            return [
                "stud-2x4-8",
                "plate-2x4-16",
                "ply-drywall-12-4x8",
                "screws-drywall-125",
                "insul-batt-r13"
            ]

        case .lvpFloor:
            return [
                "lvp-floor-7x48",
                "underlayment-foam",
                "trim-base-35",
                "caulk-painter",
                "construction-adhesive"
            ]

        case .paintRoom:
            return [
                "paint-primer",
                "paint-int-eggshell",
                "caulk-painter"
            ]

        case .basicBathRemodel:
            return [
                "cementboard-12-3x5",
                "tile-floor-porcelain",
                "thinset-modified",
                "grout-sanded",
                "membrane-waterproof",
                "gfc-outlet",
                "pex-12",
                "paint-int-eggshell",
                "caulk-painter"
            ]

        case .deckSurfaceReplace:
            return [
                "deck-board-54x16",
                "screws-deck-3"
            ]

        case .windowInstall:
            return [
                "window-foam",
                "shims-mixed",
                "drip-cap",
                "caulk-painter"
            ]
        }
    }
}
