import Foundation

struct MaterialResolutionHelper {
    static func material(
        from recommendation: MaterialRecommendation,
        catalog: MaterialsCatalogStore,
        ownerID: String,
        fallbackUnitCost: Double? = nil
    ) -> Material {
        let pricingItem = catalog.pricing(for: recommendation.name)
        let catalogPrice = pricingItem.map { catalog.price(for: $0) }
        let unitCost = safeNumber(catalogPrice ?? fallbackUnitCost ?? recommendation.estimatedUnitCost ?? 0)
        let productURL = pricingItem.flatMap { catalog.productURL(for: $0) }

        var resolvedUnit = pricingItem?.unit ?? recommendation.unit
        var purchaseQuantity = safeNumber(recommendation.quantity)
        var notes = recommendation.notes

        if let pricingItem,
           let coverageQuantity = pricingItem.coverageQuantity,
           coverageQuantity > 0,
           let coverageUnit = pricingItem.coverageUnit,
           unitsMatch(recommendation.unit, coverageUnit) {

            purchaseQuantity = (safeNumber(recommendation.quantity) / coverageQuantity).rounded(.up)
            resolvedUnit = pricingItem.unit

            let coverageNote = "~\(formattedQuantity(coverageQuantity)) \(coverageUnit) per \(pricingItem.unit)"
            if let existing = notes, !existing.isEmpty {
                notes = "\(existing) (\(coverageNote))"
            } else {
                notes = coverageNote
            }
        } else if let pricingItem, unitsMatch(recommendation.unit, pricingItem.unit) {
            resolvedUnit = pricingItem.unit
        }

        return Material(
            ownerID: ownerID,
            name: recommendation.name,
            quantity: purchaseQuantity,
            unitCost: unitCost,
            productURL: productURL,
            unit: resolvedUnit,
            notes: notes
        )
    }

    private static func unitsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        return normalizeUnit(lhs) == normalizeUnit(rhs)
    }

    private static func normalizeUnit(_ unit: String) -> String {
        let cleaned = unit
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "square", with: "sq")
            .replacingOccurrences(of: "foot", with: "ft")
            .replacingOccurrences(of: "feet", with: "ft")
        let filtered = cleaned.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }

    private static func formattedQuantity(_ value: Double) -> String {
        if value.rounded(.down) == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
