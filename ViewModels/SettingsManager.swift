import Foundation
import Combine

final class SettingsManager: ObservableObject {
    @Published var commonMaterials: [SavedMaterial] = [] {
        didSet {
            saveMaterials()
        }
    }

    private let storageKey = "estimateDefaultsMaterials"

    init() {
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
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([SavedMaterial].self, from: data) {
            commonMaterials = decoded
        }
    }

    private func saveMaterials() {
        guard let data = try? JSONEncoder().encode(commonMaterials) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
