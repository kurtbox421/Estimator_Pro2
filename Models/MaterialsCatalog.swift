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
    let productURL: URL?
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
    @Published private(set) var productURLOverrides: [String: URL] = [:] {
        didSet { saveProductURLOverrides() }
    }
    @Published private(set) var removedMaterialIDs: Set<String> = [] {
        didSet {
            saveRemovedMaterials()
            rebuildCatalog()
        }
    }

    private let persistence: PersistenceService
    private var baseMaterials: [MaterialItem] = []

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence

        loadFromBundle()
        loadCustomMaterials()
        loadRemovedMaterials()
        loadOverrides()
        loadProductURLOverrides()
        rebuildCatalog()
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
        let filteredBase = baseMaterials
            .filter { !removedMaterialIDs.contains($0.id) }
            .map { applyProductURLOverride(to: $0) }
        let filteredCustom = customMaterials
            .filter { !removedMaterialIDs.contains($0.id) }
            .map { applyProductURLOverride(to: $0) }
        materials = filteredBase + filteredCustom
    }

    @discardableResult
    func addCustomMaterial(name: String, unit: String, unitCost: Double, category: MaterialCategory, productURL: URL? = nil) -> MaterialItem {
        let newMaterial = MaterialItem(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultUnitCost: unitCost,
            productURL: productURL,
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
        defaultUnitCost: Double? = nil,
        category: MaterialCategory? = nil,
        productURL: URL?? = nil
    ) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }

        let updatedProductURL: URL?
        if let productURL {
            updatedProductURL = productURL
        } else {
            updatedProductURL = material.productURL
        }

        let updated = MaterialItem(
            id: material.id,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.name,
            category: category ?? material.category,
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.unit,
            defaultUnitCost: defaultUnitCost ?? material.defaultUnitCost,
            productURL: updatedProductURL,
            wasteFactor: material.wasteFactor,
            quantityRuleKey: material.quantityRuleKey
        )

        customMaterials[index] = updated
    }

    func deleteCustomMaterial(_ material: MaterialItem) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        customMaterials.remove(at: index)
        resetOverride(for: material.id)
        resetProductURLOverride(for: material.id)
    }

    func deleteMaterial(_ material: MaterialItem) {
        if customMaterials.contains(where: { $0.id == material.id }) {
            deleteCustomMaterial(material)
        } else {
            removedMaterialIDs.insert(material.id)
            resetOverride(for: material.id)
            resetProductURLOverride(for: material.id)
        }
    }

    var customMaterialIDs: [String] {
        customMaterials.map { $0.id }
    }

    func materials(in category: MaterialCategory) -> [MaterialItem] {
        materials.filter { $0.category == category }
    }

    func material(withID id: String) -> MaterialItem? {
        materials.compactMap { applyProductURLOverride(to: $0) }.first { $0.id == id }
    }

    func price(for material: MaterialItem) -> Double {
        priceOverrides[material.id] ?? material.defaultUnitCost
    }

    func productURL(for material: MaterialItem) -> URL? {
        productURLOverrides[material.id] ?? material.productURL
    }

    func setProductURL(_ url: URL?, for material: MaterialItem) {
        if customMaterials.contains(where: { $0.id == material.id }) {
            resetProductURLOverride(for: material.id)
            updateCustomMaterial(material, productURL: url)
            rebuildCatalog()
            return
        }

        var updated = productURLOverrides
        if let url {
            updated[material.id] = url
        } else {
            updated.removeValue(forKey: material.id)
        }
        productURLOverrides = updated
        rebuildCatalog()
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

    func resetProductURLOverride(for materialID: String) {
        guard productURLOverrides[materialID] != nil else { return }
        var updated = productURLOverrides
        updated.removeValue(forKey: materialID)
        productURLOverrides = updated
    }

    // MARK: - Overrides persistence

    private func loadOverrides() {
        if let stored: [String: Double] = persistence.load([String: Double].self, from: MaterialsCatalogStorage.overrideFileName) {
            priceOverrides = stored
        }
    }

    private func loadProductURLOverrides() {
        if let stored: [String: URL] = persistence.load([String: URL].self, from: MaterialsCatalogStorage.productURLOverridesFileName) {
            productURLOverrides = stored
        }
    }

    private func saveOverrides() {
        persistence.save(priceOverrides, to: MaterialsCatalogStorage.overrideFileName)
    }

    private func saveProductURLOverrides() {
        persistence.save(productURLOverrides, to: MaterialsCatalogStorage.productURLOverridesFileName)
    }

    private func saveCustomMaterials() {
        persistence.save(customMaterials, to: MaterialsCatalogStorage.customMaterialsFileName)
    }

    private func loadRemovedMaterials() {
        if let stored: Set<String> = persistence.load(Set<String>.self, from: MaterialsCatalogStorage.removedMaterialsFileName) {
            removedMaterialIDs = stored
        }
    }

    private func saveRemovedMaterials() {
        persistence.save(removedMaterialIDs, to: MaterialsCatalogStorage.removedMaterialsFileName)
    }

    private func applyProductURLOverride(to material: MaterialItem) -> MaterialItem {
        let override = productURLOverrides[material.id]
        guard override != nil || material.productURL != nil else { return material }

        return MaterialItem(
            id: material.id,
            name: material.name,
            category: material.category,
            unit: material.unit,
            defaultUnitCost: material.defaultUnitCost,
            productURL: override ?? material.productURL,
            wasteFactor: material.wasteFactor,
            quantityRuleKey: material.quantityRuleKey
        )
    }
}

private enum MaterialsCatalogStorage {
    static let overrideFileName = "materialPriceOverrides.json"
    static let customMaterialsFileName = "customGeneratorMaterials.json"
    static let removedMaterialsFileName = "removedMaterials.json"
    static let productURLOverridesFileName = "materialProductURLOverrides.json"
}
