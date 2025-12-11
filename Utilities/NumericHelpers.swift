import Foundation

/// Parse a `Double` from user-entered text, normalizing common formatting.
/// - Parameter text: Raw text input that may contain whitespace or comma decimals.
/// - Returns: A parsed, finite `Double` or `nil` when the value is empty or cannot be parsed.
func parseDouble(_ text: String?) -> Double? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
    guard let rawValue = Double(normalized) else { return nil }
    return sanitizeParsedNumber(rawValue)
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

/// Normalizes a parsed number to `nil` when it is not finite.
/// Keeps logging and normalization responsibilities in one place so callers avoid
/// duplicating NaN and infinity checks.
/// - Parameter value: The numeric value to inspect.
/// - Returns: `nil` when the value is NaN or infinite; otherwise the original value.
private func sanitizeParsedNumber(_ value: Double) -> Double? {
    value.isFinite ? value : nil
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
