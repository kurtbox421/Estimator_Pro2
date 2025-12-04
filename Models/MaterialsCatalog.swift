import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

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
    var ownerID: String
    var isDefault: Bool
    let name: String
    let category: MaterialCategory
    let customCategoryName: String?
    let unit: String               // "each", "sheet", "sqft", "linear_ft", "bag", etc.
    let defaultUnitCost: Double
    let productURL: URL?
    let wasteFactor: Double        // 0.10 for 10%
    let quantityRuleKey: String?   // optional, allows manual-only items

    var displayCategory: String {
        if category == .custom, let customCategoryName, !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customCategoryName
        }

        return category.displayName
    }
    init(
        id: String,
        ownerID: String = "global",
        isDefault: Bool = true,
        name: String,
        category: MaterialCategory,
        customCategoryName: String?,
        unit: String,
        defaultUnitCost: Double,
        productURL: URL?,
        wasteFactor: Double,
        quantityRuleKey: String?
    ) {
        self.id = id
        self.ownerID = ownerID
        self.isDefault = isDefault
        self.name = name
        self.category = category
        self.customCategoryName = customCategoryName
        self.unit = unit
        self.defaultUnitCost = defaultUnitCost
        self.productURL = productURL
        self.wasteFactor = wasteFactor
        self.quantityRuleKey = quantityRuleKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? "global"
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? (ownerID == "global")
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(MaterialCategory.self, forKey: .category)
        customCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        unit = try container.decode(String.self, forKey: .unit)
        defaultUnitCost = try container.decode(Double.self, forKey: .defaultUnitCost)
        productURL = try container.decodeIfPresent(URL.self, forKey: .productURL)
        wasteFactor = try container.decode(Double.self, forKey: .wasteFactor)
        quantityRuleKey = try container.decodeIfPresent(String.self, forKey: .quantityRuleKey)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case isDefault
        case name
        case category
        case customCategoryName
        case unit
        case defaultUnitCost
        case productURL
        case wasteFactor
        case quantityRuleKey
    }
}

struct MaterialsCatalog: Codable {
    let materials: [MaterialItem]
}

final class MaterialsCatalogStore: ObservableObject {
    @Published private(set) var materials: [MaterialItem] = []
    @Published private(set) var customMaterials: [MaterialItem] = [] {
        didSet { rebuildCatalog() }
    }
    @Published private(set) var priceOverrides: [String: Double] = [:] {
        didSet {
            guard !isApplyingRemoteUpdate else { return }
            persistPreferences()
        }
    }
    @Published private(set) var productURLOverrides: [String: URL] = [:] {
        didSet {
            guard !isApplyingRemoteUpdate else { return }
            persistPreferences()
        }
    }
    @Published private(set) var removedMaterialIDs: Set<String> = [] {
        didSet {
            guard !isApplyingRemoteUpdate else { return }
            persistPreferences()
            rebuildCatalog()
        }
    }

    private let db: Firestore
    private var baseMaterials: [MaterialItem] = []
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var customMaterialsListener: ListenerRegistration?
    private var preferencesListener: ListenerRegistration?
    private var currentUserID: String?
    private var isApplyingRemoteUpdate = false

    init(database: Firestore = Firestore.firestore()) {
        self.db = database

        loadFromBundle()
        rebuildCatalog()
        configureAuthListener()
    }

    deinit {
        customMaterialsListener?.remove()
        preferencesListener?.remove()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
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

    private func configureAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.attachListeners(for: user)
        }

        attachListeners(for: Auth.auth().currentUser)
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
    func addCustomMaterial(
        name: String,
        unit: String,
        unitCost: Double,
        category: MaterialCategory,
        customCategoryName: String? = nil,
        productURL: URL? = nil
    ) -> MaterialItem {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Attempted to add custom material without authenticated user")
            return MaterialItem(
                id: UUID().uuidString,
                ownerID: "",
                isDefault: false,
                name: name,
                category: category,
                customCategoryName: customCategoryName,
                unit: unit,
                defaultUnitCost: unitCost,
                productURL: productURL,
                wasteFactor: 0,
                quantityRuleKey: nil
            )
        }

        let newMaterial = MaterialItem(
            id: UUID().uuidString,
            ownerID: uid,
            isDefault: false,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            customCategoryName: customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultUnitCost: unitCost,
            productURL: productURL,
            wasteFactor: 0,
            quantityRuleKey: nil
        )

        customMaterials.append(newMaterial)
        persistCustomMaterial(newMaterial)
        return newMaterial
    }

    func updateCustomMaterial(
        _ material: MaterialItem,
        name: String? = nil,
        unit: String? = nil,
        defaultUnitCost: Double? = nil,
        category: MaterialCategory? = nil,
        customCategoryName: String?? = nil,
        productURL: URL?? = nil
    ) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }

        let updatedProductURL: URL?
        if let productURL {
            updatedProductURL = productURL
        } else {
            updatedProductURL = material.productURL
        }

        let updatedCustomCategoryName: String?
        if let customCategoryName {
            updatedCustomCategoryName = customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            updatedCustomCategoryName = material.customCategoryName
        }

        let updated = MaterialItem(
            id: material.id,
            ownerID: material.ownerID,
            isDefault: material.isDefault,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.name,
            category: category ?? material.category,
            customCategoryName: updatedCustomCategoryName,
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.unit,
            defaultUnitCost: defaultUnitCost ?? material.defaultUnitCost,
            productURL: updatedProductURL,
            wasteFactor: material.wasteFactor,
            quantityRuleKey: material.quantityRuleKey
        )

        customMaterials[index] = updated
        persistCustomMaterial(updated)
    }

    func deleteCustomMaterial(_ material: MaterialItem) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        customMaterials.remove(at: index)
        resetOverride(for: material.id)
        resetProductURLOverride(for: material.id)

        db.collection("materials")
            .document(material.id)
            .delete()
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

    private func applyProductURLOverride(to material: MaterialItem) -> MaterialItem {
        let override = productURLOverrides[material.id]
        guard override != nil || material.productURL != nil else { return material }

        return MaterialItem(
            id: material.id,
            ownerID: material.ownerID,
            isDefault: material.isDefault,
            name: material.name,
            category: material.category,
            customCategoryName: material.customCategoryName,
            unit: material.unit,
            defaultUnitCost: material.defaultUnitCost,
            productURL: override ?? material.productURL,
            wasteFactor: material.wasteFactor,
            quantityRuleKey: material.quantityRuleKey
        )
    }

    // MARK: - Firestore

    private func attachListeners(for user: User?) {
        customMaterialsListener?.remove()
        preferencesListener?.remove()

        currentUserID = user?.uid
        isApplyingRemoteUpdate = true
        customMaterials = []
        priceOverrides = [:]
        productURLOverrides = [:]
        removedMaterialIDs = []
        isApplyingRemoteUpdate = false
        rebuildCatalog()

        guard let uid = user?.uid else { return }

        customMaterialsListener = db.collection("materials")
            .whereField("ownerID", in: [uid, "global"])
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error { print("Failed to fetch materials: \(error.localizedDescription)"); return }

                let decoded: [MaterialItem] = snapshot?.documents.compactMap { document in
                    do {
                        return try document.data(as: MaterialItem.self)
                    } catch {
                        print("Failed to decode material \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                } ?? []

                DispatchQueue.main.async {
                    self.customMaterials = decoded.filter { $0.ownerID != "global" }
                }
            }

        preferencesListener = db.collection("materialPreferences")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error { print("Failed to fetch material preferences: \(error.localizedDescription)"); return }

                if let data = try? snapshot?.data(as: MaterialPreferences.self) {
                    DispatchQueue.main.async {
                        self.isApplyingRemoteUpdate = true
                        self.priceOverrides = data.priceOverrides
                        self.productURLOverrides = data.productURLOverrides
                        self.removedMaterialIDs = Set(data.removedMaterialIDs)
                        self.isApplyingRemoteUpdate = false
                        self.rebuildCatalog()
                    }
                }
            }
    }

    private func persistCustomMaterial(_ material: MaterialItem) {
        guard !material.ownerID.isEmpty else { return }

        do {
            try db.collection("materials")
                .document(material.id)
                .setData(from: material)
        } catch {
            print("Failed to save material: \(error.localizedDescription)")
        }
    }

    private func persistPreferences() {
        guard let uid = currentUserID else { return }

        let preferences = MaterialPreferences(
            id: uid,
            ownerID: uid,
            priceOverrides: priceOverrides,
            productURLOverrides: productURLOverrides,
            removedMaterialIDs: Array(removedMaterialIDs)
        )

        do {
            try db.collection("materialPreferences")
                .document(uid)
                .setData(from: preferences)
        } catch {
            print("Failed to save material preferences: \(error.localizedDescription)")
        }
    }
}
