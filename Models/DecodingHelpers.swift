import Foundation
import FirebaseFirestore

extension KeyedDecodingContainer {
    func decodeLossyDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
           let parsed = Double(stringValue) {
            return parsed
        }
        return nil
    }

    func decodeLossyDouble(forKey key: Key, default defaultValue: Double = 0) throws -> Double {
        try decodeLossyDoubleIfPresent(forKey: key) ?? defaultValue
    }

    func decodeLossyDateIfPresent(forKey key: Key) throws -> Date? {
        if let dateValue = try? decodeIfPresent(Date.self, forKey: key) {
            return dateValue
        }
        if let timestampValue = try? decodeIfPresent(Timestamp.self, forKey: key) {
            return timestampValue.dateValue()
        }
        return nil
    }
}
