import Foundation

struct MaterialsCatalogSnapshot {
    let materials: [MaterialItem]
    let materialsByTag: [MaterialJobTag: [MaterialItem]]
    let materialsByGroupID: [String: [MaterialItem]]
    let pricesByID: [String: Double]
    let productURLsByID: [String: URL?]
    let customMaterialIDs: [String]

    func materials(for jobTag: MaterialJobTag) -> [MaterialItem] {
        materialsByTag[jobTag] ?? []
    }

    func items(inGroupID groupID: String) -> [MaterialItem] {
        materialsByGroupID[groupID] ?? []
    }

    func price(for material: MaterialItem) -> Double {
        pricesByID[material.id] ?? material.defaultUnitCost
    }

    func productURL(for material: MaterialItem) -> URL? {
        productURLsByID[material.id] ?? material.productURL
    }

    func pricing(for materialName: String) -> MaterialItem? {
        let target = normalizeMaterialKey(materialName)

        if let exact = materials.first(where: { normalizeMaterialKey($0.name) == target }) {
            return exact
        }

        return materials.first { candidate in
            let normalizedCandidate = normalizeMaterialKey(candidate.name)
            return normalizedCandidate.contains(target) || target.contains(normalizedCandidate)
        }
    }

    private func normalizeMaterialKey(_ name: String) -> String {
        let cleaned = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let filteredScalars = cleaned.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }
}
