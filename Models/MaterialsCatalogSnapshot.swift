import Foundation

struct MaterialsCatalogSnapshot {
    let materialsByTag: [MaterialJobTag: [MaterialItem]]
    let pricesByID: [String: Double]
    let customMaterialIDs: [String]

    func materials(for jobTag: MaterialJobTag) -> [MaterialItem] {
        materialsByTag[jobTag] ?? []
    }

    func price(for material: MaterialItem) -> Double {
        pricesByID[material.id] ?? material.defaultUnitCost
    }
}
