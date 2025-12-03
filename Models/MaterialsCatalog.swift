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
    @Published private(set) var priceOverrides: [String: Double] = [:] {
        didSet { saveOverrides() }
    }

    private let persistence: PersistenceService

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence

        loadFromBundle()
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
            self.materials = decoded.materials
        } catch {
            print("Failed to load MaterialsCatalog.json: \(error)")
        }
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
}

private enum MaterialsCatalogStorage {
    static let overrideFileName = "materialPriceOverrides.json"
}
