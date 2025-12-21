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
        if let dateValue = try decodeIfPresent(Date.self, forKey: key) {
            return dateValue
        }
        if let timestampValue = try decodeIfPresent(Timestamp.self, forKey: key) {
            return timestampValue.dateValue()
        }
        if let doubleValue = try decodeLossyDoubleIfPresent(forKey: key) {
            return Date(timeIntervalSince1970: doubleValue)
        }
        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
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

    func decodeLossyUUIDIfPresent(forKey key: Key) throws -> UUID? {
        if let uuidValue = try? decodeIfPresent(UUID.self, forKey: key) {
            if let uuidValue {
                return uuidValue
            }
        }

        if let uuidString = try? decodeIfPresent(String.self, forKey: key) {
            if let uuidString {
                return UUID(uuidString: uuidString.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return nil
    }
}
