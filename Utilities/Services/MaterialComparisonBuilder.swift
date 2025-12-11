import Foundation

struct MaterialMatchResult: Identifiable, Hashable {
    let id = UUID()
    let catalogItem: MaterialItem
    let confidence: Double
    let matchedAttributes: [String]
    let notes: [String]

    var isHighConfidence: Bool { confidence >= 0.7 }
    var roundedConfidence: String { String(format: "%.0f%%", confidence * 100) }
}

struct MaterialConfidenceScoreBuilder {
    private let source: Material
    private let candidate: MaterialItem

    private(set) var reasons: [String] = []
    private(set) var matchedAttributes: [String] = []

    init(source: Material, candidate: MaterialItem) {
        self.source = source
        self.candidate = candidate
    }

    mutating func build() -> MaterialMatchResult {
        let nameScore = nameSimilarity()
        let unitScore = unitSimilarity()
        let costScore = costSimilarity()

        let weightedScore = (nameScore * 0.6) + (unitScore * 0.25) + (costScore * 0.15)

        return MaterialMatchResult(
            catalogItem: candidate,
            confidence: min(1.0, max(0.0, weightedScore)),
            matchedAttributes: matchedAttributes,
            notes: reasons
        )
    }

    private mutating func nameSimilarity() -> Double {
        let lhsTokens = tokenSet(from: source.name)
        let rhsTokens = tokenSet(from: candidate.name)
        let overlap = lhsTokens.intersection(rhsTokens)
        let union = lhsTokens.union(rhsTokens)

        guard !union.isEmpty else { return 0 }
        let jaccard = Double(overlap.count) / Double(union.count)

        if jaccard >= 0.6 {
            matchedAttributes.append("name")
            reasons.append("Strong keyword overlap between \(source.name) and \(candidate.name)")
        } else if jaccard > 0.3 {
            reasons.append("Partial keyword overlap between \(source.name) and \(candidate.name)")
        }

        let lengthDelta = abs(Double(source.name.count - candidate.name.count))
        let lengthScore = max(0, 1 - (lengthDelta / Double(max(source.name.count, 1))))

        return min(1.0, (jaccard * 0.7) + (lengthScore * 0.3))
    }

    private mutating func unitSimilarity() -> Double {
        guard let sourceUnit = normalizedUnit(source.unit) else { return 0.4 }
        guard let candidateUnit = normalizedUnit(candidate.unit) else { return 0.4 }

        if sourceUnit == candidateUnit {
            matchedAttributes.append("unit")
            reasons.append("Units match (\(sourceUnit))")
            return 1.0
        }

        if sourceUnit.hasPrefix(candidateUnit) || candidateUnit.hasPrefix(sourceUnit) {
            reasons.append("Units are related (\(sourceUnit) vs \(candidateUnit))")
            return 0.7
        }

        return 0.2
    }

    private mutating func costSimilarity() -> Double {
        guard candidate.defaultUnitCost > 0 else { return 0 }
        let delta = abs(candidate.defaultUnitCost - source.unitCost)
        let average = max(candidate.defaultUnitCost, source.unitCost)
        let relative = delta / max(average, 1)

        if relative <= 0.1 {
            matchedAttributes.append("cost")
            reasons.append("Unit cost is within 10% of catalog item")
            return 1.0
        }

        if relative <= 0.25 {
            reasons.append("Unit cost is within 25% of catalog item")
            return 0.6
        }

        reasons.append("Unit cost differs significantly from catalog item")
        return 0.2
    }

    private func tokenSet(from text: String) -> Set<String> {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: Set<String>()) { $0.insert($1) }
    }

    private func normalizedUnit(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value.lowercased()
    }
}

enum MaterialComparisonBuilder {
    static func bestMatches(
        for material: Material,
        catalog: MaterialsCatalog,
        limit: Int = 5
    ) -> [MaterialMatchResult] {
        let comparisons = catalog.materials.map { candidate -> MaterialMatchResult in
            var builder = MaterialConfidenceScoreBuilder(source: material, candidate: candidate)
            return builder.build()
        }

        return Array(
            comparisons
                .sorted { lhs, rhs in
                    if lhs.confidence == rhs.confidence {
                        return lhs.catalogItem.name < rhs.catalogItem.name
                    }
                    return lhs.confidence > rhs.confidence
                }
                .prefix(max(limit, 1))
        )
    }
}
