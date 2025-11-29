import Foundation
import Combine

private enum SettingsStorage {
    static let userDefaultsKey = "estimateDefaultsMaterials"
    static let fileName = "commonMaterials.json"
}

final class SettingsManager: ObservableObject {
    @Published var commonMaterials: [SavedMaterial] = [] {
        didSet {
            saveMaterials()
        }
    }

    private let persistence: PersistenceService

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        loadMaterials()
    }

    func addMaterial(name: String, price: Double) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        commonMaterials.append(SavedMaterial(name: trimmedName, price: price))
    }

    func deleteMaterials(at offsets: IndexSet) {
        commonMaterials.remove(atOffsets: offsets)
    }

    func updateMaterialName(at index: Int, name: String) {
        guard commonMaterials.indices.contains(index) else { return }

        var updatedMaterials = commonMaterials
        updatedMaterials[index].name = name
        commonMaterials = updatedMaterials
    }

    func updateMaterialPrice(at index: Int, price: Double) {
        guard commonMaterials.indices.contains(index) else { return }

        var updatedMaterials = commonMaterials
        updatedMaterials[index].price = price
        commonMaterials = updatedMaterials
    }

    func commonMaterialPrice(for name: String) -> Double? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return commonMaterials.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }?.price
    }

    private func loadMaterials() {
        if let stored: [SavedMaterial] = persistence.load([SavedMaterial].self, from: SettingsStorage.fileName) {
            commonMaterials = stored
            return
        }

        if let migrated: [SavedMaterial] = persistence.migrateFromUserDefaults(key: SettingsStorage.userDefaultsKey, fileName: SettingsStorage.fileName, as: [SavedMaterial].self) {
            commonMaterials = migrated
            return
        }

        commonMaterials = []
    }

    private func saveMaterials() {
        persistence.save(commonMaterials, to: SettingsStorage.fileName)
    }
}
