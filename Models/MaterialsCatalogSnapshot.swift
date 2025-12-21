import Foundation

struct MaterialsCatalogSnapshot {
    let materials: [MaterialItem]
    let materialsByTag: [MaterialJobTag: [MaterialItem]]
    let materialsByCategory: [MaterialCategory: [MaterialItem]]
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

    func materials(in category: MaterialCategory) -> [MaterialItem] {
        materialsByCategory[category] ?? []
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

    func preferredMaterial(
        for key: String,
        category: MaterialCategory,
        nameKeywords: [String],
        preferredUnits: [String]
    ) -> MaterialItem? {
        let candidates = materials(in: category)
        let keywordLowercased = nameKeywords.map { $0.lowercased() }
        let preferredUnitLowercased = preferredUnits.map { $0.lowercased() }

        func score(_ item: MaterialItem) -> Int {
            var value = 0

            if !item.isDefault { value += 4 }
            if item.id == key { value += 3 }

            if preferredUnitLowercased.contains(where: { unit in
                item.unit.lowercased().contains(unit)
            }) {
                value += 2
            }

            if keywordLowercased.contains(where: { keyword in
                item.name.lowercased().contains(keyword)
            }) {
                value += 1
            }

            return value
        }

        if let best = candidates.max(by: { score($0) < score($1) }) {
            return best
        }

        let keywordFallback = materials.first { item in
            keywordLowercased.contains(where: { item.name.lowercased().contains($0) })
        }

        if let keywordFallback { return keywordFallback }

        return materials.first { $0.id == key }
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
