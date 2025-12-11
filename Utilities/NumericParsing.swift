import Foundation

/// Legacy entry point for parsing optional text values.
/// Delegates to the shared `parseDouble` helper so callers don't need to change.
func safeDouble(_ text: String?) -> Double? {
    parseDouble(text)
}

/// Divides while protecting against invalid numeric results.
func safeDivide(_ numerator: Double, by denominator: Double) -> Double {
    guard denominator != 0, !denominator.isNaN else { return 0 }
    return safeNumber(numerator / denominator)
}
