import Foundation
import FirebaseFirestore

extension KeyedDecodingContainer {
    private static var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var iso8601FormatterWithoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func decodeLossyDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            let normalized = stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }
        return nil
    }

    func decodeLossyDouble(forKey key: Key, default defaultValue: Double = 0) throws -> Double {
        try decodeLossyDoubleIfPresent(forKey: key) ?? defaultValue
    }

    func decodeLossyDateIfPresent(forKey key: Key) throws -> Date? {
        if let dateValue = try? decodeIfPresent(Date.self, forKey: key), let dateValue {
            return dateValue
        }
        if let timestampValue = try? decodeIfPresent(Timestamp.self, forKey: key), let timestampValue {
            return timestampValue.dateValue()
        }
        if let doubleValue = try? decodeLossyDoubleIfPresent(forKey: key), let doubleValue {
            return Date(timeIntervalSince1970: doubleValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key), let stringValue {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let dateValue = Self.iso8601Formatter.date(from: trimmed) {
                return dateValue
            }
            if let dateValue = Self.iso8601FormatterWithoutFractional.date(from: trimmed) {
                return dateValue
            }
        }
        return nil
    }
}
