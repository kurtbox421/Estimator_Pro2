import Foundation

/// Lightweight JSON-based persistence layer for storing small data sets on device.
/// Files are saved to the app's document directory to keep data available between launches.
final class PersistenceService {
    static let shared = PersistenceService()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Loading

    /// Loads and decodes a value of type `T` from the given file, if it exists.
    func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = fileURL(for: fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            print("[PersistenceService] Failed to load \(fileName): \(error)")
            return nil
        }
    }

    // MARK: - Saving

    /// Encodes and saves a value of type `T` to the given file.
    func save<T: Encodable>(_ value: T, to fileName: String) {
        let url = fileURL(for: fileName)

        do {
            let data = try encoder.encode(value)
            try fileManager.createDirectory(at: directoryURL,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[PersistenceService] Failed to save \(fileName): \(error)")
        }
    }

    // MARK: - Migration helpers

    /// Migrates a value previously stored in `UserDefaults` (as Data) into a file on disk.
    /// Type `T` must be codable because it is both decoded and then re-encoded.
    func migrateFromUserDefaults<T: Codable>(
        key: String,
        fileName: String,
        as type: T.Type
    ) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        do {
            let decoded = try decoder.decode(type, from: data)
            save(decoded, to: fileName)
            UserDefaults.standard.removeObject(forKey: key)
            return decoded
        } catch {
            print("[PersistenceService] Migration for \(key) failed: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func fileURL(for fileName: String) -> URL {
        return directoryURL.appendingPathComponent(fileName)
    }
}

