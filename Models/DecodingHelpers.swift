import Foundation
import FirebaseFirestore

extension KeyedDecodingContainer {
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

    func decodeLossyDateIfPresent(forKey key: Key) throws -> Date? {
        if let dateValue = try? decodeIfPresent(Date.self, forKey: key) {
            return dateValue
        }
        if let timestampValue = try? decodeIfPresent(Timestamp.self, forKey: key) {
            return timestampValue.dateValue()
        }
        if let timestampDictionary = try? decodeIfPresent([String: Double].self, forKey: key) {
            if let dateValue = Self.date(fromTimestampDictionary: timestampDictionary) {
                return dateValue
            }
        }
        if let timestampDictionary = try? decodeIfPresent([String: Int].self, forKey: key) {
            if let dateValue = Self.date(fromTimestampDictionary: timestampDictionary) {
                return dateValue
            }
        }
        if let doubleValue = try? decodeLossyDoubleIfPresent(forKey: key) {
            return Date(timeIntervalSince1970: doubleValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let dateValue = formatterWithFractional.date(from: trimmed) {
                return dateValue
            }
            let formatterWithoutFractional = ISO8601DateFormatter()
            formatterWithoutFractional.formatOptions = [.withInternetDateTime]
            return formatterWithoutFractional.date(from: trimmed)
        }
        return nil
    }

    private static func date(fromTimestampDictionary dictionary: [String: Double]) -> Date? {
        guard let seconds = dictionary["seconds"] else {
            return nil
        }
        let nanos = dictionary["nanoseconds"] ?? 0
        return Date(timeIntervalSince1970: seconds + nanos / 1_000_000_000)
    }

    private static func date(fromTimestampDictionary dictionary: [String: Int]) -> Date? {
        guard let seconds = dictionary["seconds"] else {
            return nil
        }
        let nanos = dictionary["nanoseconds"] ?? 0
        return Date(timeIntervalSince1970: Double(seconds) + Double(nanos) / 1_000_000_000)
    }

    func decodeLossyUUIDIfPresent(forKey key: Key) throws -> UUID? {
        if let uuid = try decodeIfPresent(UUID.self, forKey: key) {
            return uuid
        }
        if let s = try decodeIfPresent(String.self, forKey: key) {
            return UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
