import Foundation

/// Parse a `Double` from user-entered text.
/// - Parameter text: Raw text input that may contain whitespace.
/// - Returns: A parsed `Double` or `nil` when the value is empty or cannot be parsed.
func parseDouble(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return Double(trimmed)
}

/// Prevents propagation of invalid numeric values by normalizing NaN or infinity to zero.
/// - Parameters:
///   - value: The numeric value to validate.
///   - label: Context label used for logging.
/// - Returns: The original value when finite; otherwise `0`.
func debugCheckNaN(_ value: Double, label: String) -> Double {
    guard value.isFinite else {
        print("⚠️ Invalid numeric value for \(label): \(value)")
        return 0
    }
    return value
}

/// Normalizes a numeric value so UI and calculations never receive NaN or infinity.
/// - Parameter value: Any `Double` value.
/// - Returns: `0` when the value is not finite; otherwise the original value.
private func sanitizeNumber(_ value: Double) -> Double {
    value.isFinite ? value : 0
}

func safeNumber(_ value: Double) -> Double {
    sanitizeNumber(value)
}

/// Overload that passes through `nil` while sanitizing real values.
/// - Parameter value: Optional numeric input.
/// - Returns: `nil` when the input is `nil`; otherwise a finite value.
func safeNumber(_ value: Double?) -> Double? {
    guard let value else { return nil }
    return sanitizeNumber(value)
}
