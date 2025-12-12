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

enum MaterialGroupTemplateType: String, Codable, CaseIterable, Identifiable {
    case interiorWallBuild
    case lvpFlooring
    case paintRoom
    case basicBathroomRemodel
    case exteriorPaint
    case tileBacksplash
    case deckBuild
    case roofShingleReplacement

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .interiorWallBuild: return "Interior Wall Build"
        case .lvpFlooring: return "LVP Flooring"
        case .paintRoom: return "Paint Room"
        case .basicBathroomRemodel: return "Basic Bathroom Remodel"
        case .exteriorPaint: return "Exterior Paint"
        case .tileBacksplash: return "Tile Backsplash"
        case .deckBuild: return "Deck Build"
        case .roofShingleReplacement: return "Roof Shingle Replacement"
        }
    }

    var jobType: MaterialJobType {
        switch self {
        case .interiorWallBuild: return .interiorWallBuild
        case .lvpFlooring: return .lvpFlooring
        case .paintRoom: return .paintRoom
        case .basicBathroomRemodel: return .basicBathroomRemodel
        case .exteriorPaint: return .exteriorPaint
        case .tileBacksplash: return .tileBacksplash
        case .deckBuild: return .deckBuild
        case .roofShingleReplacement: return .roofShingleReplacement
        }
    }

    init?(jobTag: MaterialJobTag) {
        switch jobTag {
        case .interiorWallBuild: self = .interiorWallBuild
        case .lvpFlooring: self = .lvpFlooring
        case .paintRoom: self = .paintRoom
        case .basicBathroomRemodel: self = .basicBathroomRemodel
        case .deckSurfaceReplace: self = .deckBuild
        case .windowInstall: self = .exteriorPaint
        case .exteriorPaint: self = .exteriorPaint
        case .tileBacksplash: self = .tileBacksplash
        case .deckBuild: self = .deckBuild
        case .roofShingleReplacement: self = .roofShingleReplacement
        }
    }
}

struct MaterialGroup: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var sortOrder: Int
    var templateType: MaterialGroupTemplateType

    static func defaults() -> [MaterialGroup] {
        MaterialCategory.allCases.enumerated().compactMap { index, category in
            let name = category.displayName
            let groupID = MaterialItem.groupID(for: category, customCategoryName: nil)
            guard let template = MaterialGroupTemplateType(jobTag: MaterialItem.defaultJobType(for: category).jobTag) else { return nil }

            return MaterialGroup(
                id: groupID,
                name: name,
                sortOrder: index,
                templateType: template
            )
        }
    }
}

enum MaterialJobTag: String, Codable, CaseIterable, Identifiable {
    case interiorWallBuild
    case lvpFlooring
    case paintRoom
    case basicBathroomRemodel
    case deckSurfaceReplace
    case windowInstall
    case exteriorPaint
    case tileBacksplash
    case deckBuild
    case roofShingleReplacement

    var id: String { rawValue }
}

struct MaterialItem: Identifiable, Codable, Hashable {
    let id: String
    var ownerID: String
    var isDefault: Bool
    let name: String
    let category: MaterialCategory
    let customCategoryName: String?
    let groupID: String
    let unit: String               // "each", "sheet", "sqft", "linear_ft", "bag", etc.
    let defaultUnitCost: Double
    let productURL: URL?
    let coverageQuantity: Double?  // Optional logical coverage (e.g. 30 sq ft per box)
    let coverageUnit: String?      // Unit the coverageQuantity is expressed in (sq ft, lf, etc.)
    let wasteFactor: Double        // 0.10 for 10%
    let quantityRuleKey: String?   // optional, allows manual-only items
    let jobType: MaterialJobType

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
        groupID: String? = nil,
        unit: String,
        defaultUnitCost: Double,
        productURL: URL?,
        coverageQuantity: Double? = nil,
        coverageUnit: String? = nil,
        wasteFactor: Double,
        quantityRuleKey: String?,
        jobType: MaterialJobType? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.isDefault = isDefault
        self.name = name
        self.category = category
        self.customCategoryName = customCategoryName
        self.groupID = groupID ?? MaterialItem.groupID(for: category, customCategoryName: customCategoryName)
        self.unit = unit
        self.defaultUnitCost = defaultUnitCost
        self.productURL = productURL
        self.coverageQuantity = coverageQuantity
        self.coverageUnit = coverageUnit
        self.wasteFactor = wasteFactor
        self.quantityRuleKey = quantityRuleKey
        self.jobType = jobType ?? MaterialItem.defaultJobType(for: category)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID) ?? "global"
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? true
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(MaterialCategory.self, forKey: .category)
        customCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID) ?? MaterialItem.groupID(for: category, customCategoryName: customCategoryName)
        unit = try container.decode(String.self, forKey: .unit)
        defaultUnitCost = try container.decode(Double.self, forKey: .defaultUnitCost)
        productURL = try container.decodeIfPresent(URL.self, forKey: .productURL)
        coverageQuantity = try container.decodeIfPresent(Double.self, forKey: .coverageQuantity)
        coverageUnit = try container.decodeIfPresent(String.self, forKey: .coverageUnit)
        wasteFactor = try container.decodeIfPresent(Double.self, forKey: .wasteFactor) ?? 0
        quantityRuleKey = try container.decodeIfPresent(String.self, forKey: .quantityRuleKey)
        jobType = try container.decodeIfPresent(MaterialJobType.self, forKey: .jobType) ?? .interiorWallBuild
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID
        case isDefault
        case name
        case category
        case customCategoryName
        case groupID
        case unit
        case defaultUnitCost
        case productURL
        case coverageQuantity
        case coverageUnit
        case wasteFactor
        case quantityRuleKey
        case jobType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(customCategoryName, forKey: .customCategoryName)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(unit, forKey: .unit)
        try container.encode(defaultUnitCost, forKey: .defaultUnitCost)
        try container.encodeIfPresent(productURL, forKey: .productURL)
        try container.encodeIfPresent(coverageQuantity, forKey: .coverageQuantity)
        try container.encodeIfPresent(coverageUnit, forKey: .coverageUnit)
        try container.encode(wasteFactor, forKey: .wasteFactor)
        try container.encodeIfPresent(quantityRuleKey, forKey: .quantityRuleKey)
        try container.encode(jobType, forKey: .jobType)
    }

    static func defaultJobType(for category: MaterialCategory) -> MaterialJobType {
        switch category {
        case .lumberFraming, .sheetgoods, .drywallBacker, .insulation, .hardwareFasteners, .hardwareConnectors:
            return .interiorWallBuild
        case .flooring:
            return .lvpFlooring
        case .paint, .sealants, .trimFinish:
            return .paintRoom
        case .tileMaterials, .tile:
            return .tileBacksplash
        case .concreteMasonry, .exteriorDecking, .exteriorStructural:
            return .deckBuild
        case .exteriorFlashing:
            return .roofShingleReplacement
        case .electrical:
            return .interiorWallBuild
        case .plumbing:
            return .basicBathroomRemodel
        case .hardwareMisc:
            return .interiorWallBuild
        case .custom:
            return .interiorWallBuild
        }
    }

    static func groupID(for category: MaterialCategory, customCategoryName: String?) -> String {
        if category == .custom,
           let customCategoryName,
           !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customCategoryName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
        }

        return category.rawValue
    }
}

struct MaterialsCatalog: Codable {
    let materials: [MaterialItem]
}

final class MaterialsCatalogStore: ObservableObject {
    @Published private(set) var materials: [MaterialItem] = []
    @Published private(set) var materialGroups: [MaterialGroup] = []
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
        rebuildGroups()
    }

    private func rebuildGroups() {
        let groupedByID = Dictionary(grouping: materials) { $0.groupID }
        let defaultGroups = MaterialGroup.defaults()
        var resolved: [MaterialGroup] = []

        for group in defaultGroups {
            guard let items = groupedByID[group.id] else { continue }
            resolved.append(
                MaterialGroup(
                    id: group.id,
                    name: group.name,
                    sortOrder: group.sortOrder,
                    templateType: templateType(for: items)
                )
            )
        }

        let defaultIDs = Set(defaultGroups.map { $0.id })
        let customGroups = groupedByID.filter { !defaultIDs.contains($0.key) }
        for (index, entry) in customGroups.sorted(by: { $0.key < $1.key }).enumerated() {
            let items = entry.value
            resolved.append(
                MaterialGroup(
                    id: entry.key,
                    name: items.first?.displayCategory ?? entry.key,
                    sortOrder: defaultGroups.count + index,
                    templateType: templateType(for: items)
                )
            )
        }

        materialGroups = resolved.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func templateType(for items: [MaterialItem]) -> MaterialGroupTemplateType {
        let tags = items.map { $0.jobType.jobTag }

        if let mostCommon = tags.reduce(into: [:]) { counts, tag in
            counts[tag, default: 0] += 1
        }.max(by: { $0.value < $1.value })?.key,
           let template = MaterialGroupTemplateType(jobTag: mostCommon) {
            return template
        }

        if let firstTag = tags.first, let template = MaterialGroupTemplateType(jobTag: firstTag) {
            return template
        }

        return .interiorWallBuild
    }

    func materials(in group: MaterialGroup) -> [MaterialItem] {
        items(inGroupID: group.id)
    }

    func items(inGroupID groupID: String) -> [MaterialItem] {
        materials
            .filter { $0.groupID == groupID }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Material lookup / normalization

    func material(matchingName name: String) -> MaterialItem? {
        let target = normalizeMaterialKey(name)

        if let exact = materials.first(where: { normalizeMaterialKey($0.name) == target }) {
            return exact
        }

        // Fall back to partial match in case of formatting differences (punctuation, units, etc.)
        return materials.first { candidate in
            let normalizedCandidate = normalizeMaterialKey(candidate.name)
            return normalizedCandidate.contains(target) || target.contains(normalizedCandidate)
        }
    }

    func normalizedPrice(forName name: String) -> (override: Double?, defaultPrice: Double?) {
        guard let material = material(matchingName: name) else { return (nil, nil) } 
        let overridePrice = override(for: material.id)
        return (overridePrice, material.defaultUnitCost)
    }

    func pricing(for materialName: String) -> MaterialItem? {
        material(matchingName: materialName)
    }

    func preferredMaterial(
        for generatorID: String?,
        category: MaterialCategory,
        nameKeywords: [String] = [],
        preferredUnits: [String] = []
    ) -> MaterialItem? {
        let candidates = materials(in: category)
        let keywordLowercased = nameKeywords.map { $0.lowercased() }
        let preferredUnitLowercased = preferredUnits.map { $0.lowercased() }

        func score(_ item: MaterialItem) -> Int {
            var value = 0

            if !item.isDefault { value += 4 }
            if let generatorID, item.id == generatorID { value += 3 }

            if preferredUnitLowercased.contains(where: { unit in
                item.unit.lowercased().contains(unit)
            }) {
                value += 2
            }

            if keywordLowercased.contains(where: { keyword in
                item.name.lowercased().contains(keyword)
            }) {
                value += 1
            }

            return value
        }

        if let best = candidates.max(by: { score($0) < score($1) }) {
            return best
        }

        let keywordFallback = materials.first { item in
            keywordLowercased.contains(where: { item.name.lowercased().contains($0) })
        }

        if let keywordFallback { return keywordFallback }

        if let generatorID {
            return materials.first { $0.id == generatorID }
        }

        return nil
    }

    func pricePerUnit(for materialName: String) -> Double? {
        guard let material = pricing(for: materialName) else { return nil }
        return price(for: material)
    }

    func coverage(for materialName: String) -> (quantity: Double, unit: String)? {
        guard let material = pricing(for: materialName),
              let quantity = material.coverageQuantity,
              let unit = material.coverageUnit else { return nil }
        return (quantity, unit)
    }

    func normalizeMaterialKey(_ name: String) -> String {
        let cleaned = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let filteredScalars = cleaned.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    @discardableResult
    func addCustomMaterial(
        name: String,
        unit: String,
        unitCost: Double,
        category: MaterialCategory,
        customCategoryName: String? = nil,
        productURL: URL? = nil,
        coverageQuantity: Double? = nil,
        coverageUnit: String? = nil,
        wasteFactor: Double = 0
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
                groupID: MaterialItem.groupID(for: category, customCategoryName: customCategoryName),
                unit: unit,
                defaultUnitCost: unitCost,
                productURL: productURL,
                coverageQuantity: coverageQuantity,
                coverageUnit: coverageUnit,
                wasteFactor: wasteFactor,
                quantityRuleKey: nil,
                jobType: MaterialItem.defaultJobType(for: category)
            )
        }

        let newMaterial = MaterialItem(
            id: UUID().uuidString,
            ownerID: uid,
            isDefault: false,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            customCategoryName: customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
            groupID: MaterialItem.groupID(for: category, customCategoryName: customCategoryName),
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultUnitCost: unitCost,
            productURL: productURL,
            coverageQuantity: coverageQuantity,
            coverageUnit: coverageUnit,
            wasteFactor: wasteFactor,
            quantityRuleKey: nil,
            jobType: MaterialItem.defaultJobType(for: category)
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
        productURL: URL?? = nil,
        coverageQuantity: Double?? = nil,
        coverageUnit: String?? = nil,
        wasteFactor: Double?? = nil
    ) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }

        let updatedProductURL: URL?
        if let productURL {
            updatedProductURL = productURL
        } else {
            updatedProductURL = material.productURL
        }

        let updatedCoverageQuantity: Double?
        if let coverageQuantity {
            updatedCoverageQuantity = coverageQuantity ?? material.coverageQuantity
        } else {
            updatedCoverageQuantity = material.coverageQuantity
        }

        let updatedCoverageUnit: String?
        if let coverageUnit {
            updatedCoverageUnit = coverageUnit ?? material.coverageUnit
        } else {
            updatedCoverageUnit = material.coverageUnit
        }

        let updatedWasteFactor: Double
        if let wasteFactor {
            updatedWasteFactor = wasteFactor ?? material.wasteFactor
        } else {
            updatedWasteFactor = material.wasteFactor
        }

        let updatedCustomCategoryName: String?
        if let customCategoryName {
            updatedCustomCategoryName = customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            updatedCustomCategoryName = material.customCategoryName
        }

        let resolvedCategory = category ?? material.category
        let resolvedGroupID = MaterialItem.groupID(for: resolvedCategory, customCategoryName: updatedCustomCategoryName)
        let updated = MaterialItem(
            id: material.id,
            ownerID: material.ownerID,
            isDefault: material.isDefault,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.name,
            category: resolvedCategory,
            customCategoryName: updatedCustomCategoryName,
            groupID: resolvedGroupID,
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? material.unit,
            defaultUnitCost: defaultUnitCost ?? material.defaultUnitCost,
            productURL: updatedProductURL,
            coverageQuantity: updatedCoverageQuantity,
            coverageUnit: updatedCoverageUnit,
            wasteFactor: updatedWasteFactor,
            quantityRuleKey: material.quantityRuleKey,
            jobType: category != nil ? MaterialItem.defaultJobType(for: resolvedCategory) : material.jobType
        )

        customMaterials[index] = updated
        persistCustomMaterial(updated)
    }

    func deleteCustomMaterial(_ material: MaterialItem) {
        guard let index = customMaterials.firstIndex(where: { $0.id == material.id }) else { return }
        customMaterials.remove(at: index)
        resetOverride(for: material.id)
        resetProductURLOverride(for: material.id)

        guard let uid = currentUserID else { return }

        db.collection("users")
            .document(uid)
            .collection("materials")
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

    func materials(
        for jobTag: MaterialJobTag,
        in categories: [MaterialCategory]? = nil
    ) -> [MaterialItem] {
        materials.filter { item in
            guard item.jobType.jobTag == jobTag else { return false }

            if let categories {
                return categories.contains(item.category)
            }

            return true
        }
    }

    func materials(
        for jobType: MaterialJobType,
        in categories: [MaterialCategory]? = nil
    ) -> [MaterialItem] {
        materials(
            for: jobType.jobTag,
            in: categories
        )
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
            groupID: material.groupID,
            unit: material.unit,
            defaultUnitCost: material.defaultUnitCost,
            productURL: override ?? material.productURL,
            coverageQuantity: material.coverageQuantity,
            coverageUnit: material.coverageUnit,
            wasteFactor: material.wasteFactor,
            quantityRuleKey: material.quantityRuleKey,
            jobType: material.jobType
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

        customMaterialsListener = db.collection("users")
            .document(uid)
            .collection("materials")
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

                DispatchQueue.main.async { self.customMaterials = decoded }
            }

        preferencesListener = db.collection("users")
            .document(uid)
            .collection("materialPreferences")
            .document("preferences")
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
        guard !material.ownerID.isEmpty, let uid = currentUserID else { return }

        do {
            try db.collection("users")
                .document(uid)
                .collection("materials")
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
            try db.collection("users")
                .document(uid)
                .collection("materialPreferences")
                .document("preferences")
                .setData(from: preferences)
        } catch {
            print("Failed to save material preferences: \(error.localizedDescription)")
        }
    }
}
