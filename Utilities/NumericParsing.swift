import Foundation

func safeDouble(_ text: String?) -> Double? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
    guard let value = Double(normalized) else { return nil }
    return safeNumber(value)
}

func parseDouble(_ text: String?) -> Double? {
    safeDouble(text)
}

func safeNumber(_ x: Double) -> Double {
    x.isNaN || x.isInfinite ? 0 : x
}

func safeDivide(_ numerator: Double, by denominator: Double) -> Double {
    guard denominator != 0, !denominator.isNaN else { return 0 }
    let result = numerator / denominator
    return safeNumber(result)
}

func debugCheckNaN(_ value: Double, label: String) -> Double {
    let sanitized = safeNumber(value)
    if sanitized != value {
        print("⚠️ NaN detected for \(label)")
    }
    return sanitized
}
