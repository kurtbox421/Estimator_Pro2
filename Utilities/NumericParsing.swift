import Foundation

func parseDouble(_ text: String?) -> Double? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return Double(trimmed.replacingOccurrences(of: ",", with: "."))
}

func safeDivide(_ numerator: Double, by denominator: Double) -> Double {
    guard denominator != 0, !denominator.isNaN else { return 0 }
    let result = numerator / denominator
    return result.isNaN || result.isInfinite ? 0 : result
}

func debugCheckNaN(_ value: Double, label: String) -> Double {
    if value.isNaN || value.isInfinite {
        print("⚠️ NaN detected for \(label)")
        return 0
    }
    return value
}
