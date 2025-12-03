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
}

/// Connects job types -> list of material IDs + provided context
struct JobMaterialGenerator {

    let catalog: MaterialsCatalogStore
    let engine = MaterialQuantityEngine()

    func generateMaterials(
        for jobType: JobType,
        context: QuantityContext
    ) -> [GeneratedMaterial] {
        let materialIDs = materialIDs(for: jobType)

        return materialIDs.compactMap { id in
            guard let material = catalog.material(withID: id) else { return nil }
            let qty = engine.quantity(for: material, context: context)
            guard qty > 0 else { return nil }
            return GeneratedMaterial(
                material: material,
                quantity: qty,
                unitCost: catalog.price(for: material)
            )
        }
    }

    func allMaterialIDs() -> [String] {
        let ids = JobType.allCases.flatMap { materialIDs(for: $0) }
        return Array(Set(ids)).sorted()
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
