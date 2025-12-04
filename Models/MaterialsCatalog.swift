import Foundation

enum MaterialCategory: String, Codable, CaseIterable, Identifiable {
    case lumberFraming      = "lumber_framing"
    case sheetgoods         = "sheetgoods"
    case drywallBacker      = "drywall_backer"
    case tileMaterials      = "tile_materials"
    case tile               = "tile"
    case flooring           = "flooring"
    case trimFinish         = "trim_finish"
    case paint              = "paint"
    case sealants           = "sealants"
    case hardwareFasteners  = "hardware_fasteners"
    case hardwareConnectors = "hardware_connectors"
    case hardwareMisc       = "hardware_misc"
    case insulation         = "insulation"
    case concreteMasonry    = "concrete_masonry"
    case exteriorDecking    = "exterior_decking"
    case exteriorStructural = "exterior_structural"
    case exteriorFlashing   = "exterior_flashing"
    case electrical         = "electrical"
    case plumbing           = "plumbing"
    case custom             = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lumberFraming:      return "Lumber & Framing"
        case .sheetgoods:         return "Sheet Goods"
        case .drywallBacker:      return "Drywall & Backerboard"
        case .tileMaterials:      return "Tile Materials"
        case .tile:               return "Tile"
        case .flooring:           return "Flooring"
        case .trimFinish:         return "Trim & Finish"
        case .paint:              return "Paint"
        case .sealants:           return "Caulk & Sealants"
        case .hardwareFasteners:  return "Fasteners"
        case .hardwareConnectors: return "Connectors & Hangers"
        case .hardwareMisc:       return "Misc Hardware"
        case .insulation:         return "Insulation"
        case .concreteMasonry:    return "Concrete & Masonry"
        case .exteriorDecking:    return "Decking"
        case .exteriorStructural: return "Exterior Structural"
        case .exteriorFlashing:   return "Flashing"
        case .electrical:         return "Electrical"
        case .plumbing:           return "Plumbing"
        case .custom:             return "Custom"
        }
    }
}

struct MaterialItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: MaterialCategory
    let unit: String               // "each", "sheet", "sqft", "linear_ft", "bag", etc.
    let defaultUnitCost: Double
    let wasteFactor: Double        // 0.10 for 10%
    let quantityRuleKey: String?   // optional, allows manual-only items

    var displayCategory: String {
        category.displayName
    }
}

struct MaterialsCatalog: Codable {
    let materials: [MaterialItem]
}

final class MaterialsCatalogStore: ObservableObject {
    @Published private(set) var materials: [MaterialItem] = []
    @Published private(set) var customMaterials: [MaterialItem] = [] {
        didSet {
            saveCustomMaterials()
            rebuildCatalog()
        }
    }
    @Published private(set) var priceOverrides: [String: Double] = [:] {
        didSet { saveOverrides() }
    }

    private let persistence: PersistenceService
    private var baseMaterials: [MaterialItem] = []

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence

        loadFromBundle()
        loadCustomMaterials()
        rebuildCatalog()
        loadOverrides()
    }

    private func loadFromBundle() {
        guard let url = Bundle.main.url(forResource: "MaterialsCatalog", withExtension: "json") else {
            print("MaterialsCatalog.json not found")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(MaterialsCatalog.self, from: data)
            baseMaterials = decoded.materials
        } catch {
            print("Failed to load MaterialsCatalog.json: \(error)")
        }
    }

    private func loadCustomMaterials() {
        if let stored: [MaterialItem] = persistence.load([MaterialItem].self, from: MaterialsCatalogStorage.customMaterialsFileName) {
            customMaterials = stored
        }
    }

    private func rebuildCatalog() {
        materials = baseMaterials + customMaterials
    }

    @discardableResult
    func addCustomMaterial(name: String, unit: String, unitCost: Double) -> MaterialItem {
        let newMaterial = MaterialItem(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: .custom,
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultUnitCost: unitCost,
            wasteFactor: 0,
            quantityRuleKey: nil
        )

        customMaterials.append(newMaterial)
        return newMaterial
    }

    func updateCustomMaterial(
        _ material: MaterialItem,
        name: String? = nil,
        unit: String? = nil,
        defaultUnitCost: Double? = nil
    ) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }

        let updated = MaterialItem(
            id: material.id,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.name,
            category: .custom,
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.unit,
            defaultUnitCost: defaultUnitCost ?? material.defaultUnitCost,
            wasteFactor: material.wasteFactor,
            quantityRuleKey: material.quantityRuleKey
        )

        customMaterials[index] = updated
    }

    func deleteCustomMaterial(_ material: MaterialItem) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        customMaterials.remove(at: index)
        resetOverride(for: material.id)
    }

    var customMaterialIDs: [String] {
        customMaterials.map { $0.id }
    }

    func materials(in category: MaterialCategory) -> [MaterialItem] {
        materials.filter { $0.category == category }
    }

    func material(withID id: String) -> MaterialItem? {
        materials.first { $0.id == id }
    }

    func price(for material: MaterialItem) -> Double {
        priceOverrides[material.id] ?? material.defaultUnitCost
    }

    func override(for materialID: String) -> Double? {
        priceOverrides[materialID]
    }

    func setPriceOverride(_ value: Double, for materialID: String) {
        var updated = priceOverrides
        updated[materialID] = value
        priceOverrides = updated
    }

    func resetOverride(for materialID: String) {
        guard priceOverrides[materialID] != nil else { return }
        var updated = priceOverrides
        updated.removeValue(forKey: materialID)
        priceOverrides = updated
    }

    // MARK: - Overrides persistence

    private func loadOverrides() {
        if let stored: [String: Double] = persistence.load([String: Double].self, from: MaterialsCatalogStorage.overrideFileName) {
            priceOverrides = stored
        }
    }

    private func saveOverrides() {
        persistence.save(priceOverrides, to: MaterialsCatalogStorage.overrideFileName)
    }

    private func saveCustomMaterials() {
        persistence.save(customMaterials, to: MaterialsCatalogStorage.customMaterialsFileName)
    }
}

private enum MaterialsCatalogStorage {
    static let overrideFileName = "materialPriceOverrides.json"
    static let customMaterialsFileName = "customGeneratorMaterials.json"
}
