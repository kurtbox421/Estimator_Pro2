import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import os.log

struct MaterialUsageStats: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let name: String
    let totalUsageCount: Int
    let averageQuantity: Double?
    let averageUnitCost: Double?
    let lastUsedAt: Date?
    let jobTypes: [String: Int]
    let mostCommonUnit: String?
}

@MainActor
final class MaterialIntelligenceStore: ObservableObject {
    @Published private(set) var materialStats: [MaterialUsageStats] = []

    private let db: Firestore
    private let logger = Logger(subsystem: "com.estimatorpro.materials", category: "MaterialIntelligenceStore")
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var jobsListener: ListenerRegistration?
    private var invoicesListener: ListenerRegistration?
    private var cachedJobs: [Job] = []
    private var cachedInvoices: [Invoice] = []
    private var invalidJobDocumentPaths: Set<String> = []
    private var coOccurrence: [String: [String: Int]] = [:]

    init(database: Firestore = Firestore.firestore()) {
        self.db = database
        configureAuthListener()
    }

    deinit {
        jobsListener?.remove()
        invoicesListener?.remove()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    func frequentlyUsedMaterials(limit: Int) -> [MaterialUsageStats] {
        let sorted = materialStats.sorted { lhs, rhs in
            if lhs.totalUsageCount == rhs.totalUsageCount {
                return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
            return lhs.totalUsageCount > rhs.totalUsageCount
        }
        return Array(sorted.prefix(limit))
    }

    func materials(forJobType jobType: String, limit: Int) -> [MaterialUsageStats] {
        let filtered = materialStats.filter { stats in
            stats.jobTypes.keys.contains(where: { $0.localizedCaseInsensitiveContains(jobType) })
        }
        return Array(filtered.sorted(by: sortByUsage).prefix(limit))
    }

    func commonlyUsed(withMaterialName name: String, limit: Int) -> [MaterialUsageStats] {
        let key = normalize(name)
        guard let coUsed = coOccurrence[key] else { return [] }

        let sortedKeys = coUsed.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
        let matchingStats: [MaterialUsageStats] = sortedKeys.compactMap { entry in
            materialStats.first { normalize($0.name) == entry.key }
        }

        return Array(matchingStats.prefix(limit))
    }

    private func configureAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.attachListeners(for: user)
        }
        attachListeners(for: Auth.auth().currentUser)
    }

    private func attachListeners(for user: User?) {
        jobsListener?.remove()
        invoicesListener?.remove()
        materialStats = []
        coOccurrence = [:]
        invalidJobDocumentPaths = []

        guard let uid = user?.uid else { return }

        jobsListener = db.collection("users")
            .document(uid)
            .collection("jobs")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.logger.error("Failed to fetch jobs: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else {
                    self.logger.error("Failed to fetch jobs: missing snapshot")
                    return
                }

                let jobs: [Job] = snapshot.documents.compactMap { document in
                    let documentPath = document.reference.path
                    if self.invalidJobDocumentPaths.contains(documentPath) {
                        return nil
                    }

                    do {
                        return try document.data(as: Job.self)
                    } catch let decodingError as DecodingError {
                        self.logJobDecodingError(decodingError, documentPath: documentPath)
                        self.invalidJobDocumentPaths.insert(documentPath)
                        return nil
                    } catch {
                        self.logger.error("Failed to decode job document \(documentPath): \(error.localizedDescription)")
                        self.invalidJobDocumentPaths.insert(documentPath)
                        return nil
                    }
                }

                self.cachedJobs = jobs
                self.rebuildStats()
            }

        invoicesListener = db.collection("users")
            .document(uid)
            .collection("invoices")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.logger.error("Failed to fetch invoices: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else {
                    self.logger.error("Failed to fetch invoices: missing snapshot")
                    return
                }

                let invoices: [Invoice] = snapshot.documents.compactMap { document in
                    do {
                        return try document.data(as: Invoice.self)
                    } catch {
                        self.logger.error("Failed to decode invoice \(document.documentID): \(error.localizedDescription)")
                        return nil
                    }
                }

                self.cachedInvoices = invoices
                self.rebuildStats()
            }
    }

    private func rebuildStats() {
        let jobs = cachedJobs
        let invoices = cachedInvoices

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            var statsMap: [String: MaterialStatsBuilder] = [:]
            var coUse: [String: [String: Int]] = [:]

            for job in jobs {
                let materials = job.materials
                let normalizedNames = Set(materials.map { normalize($0.name) })

                for material in materials {
                    accumulate(material, jobType: job.category, date: job.dateCreated, into: &statsMap)
                }

                trackCoOccurrence(normalizedNames, store: &coUse)
            }

            for invoice in invoices {
                let materials = invoice.materials
                let normalizedNames = Set(materials.map { normalize($0.name) })
                let timestamp = invoice.dueDate ?? Date()
                let jobType = invoice.title

                for material in materials {
                    accumulate(material, jobType: jobType, date: timestamp, into: &statsMap)
                }

                trackCoOccurrence(normalizedNames, store: &coUse)
            }

            let finalStats: [MaterialUsageStats] = statsMap.values.map { $0.build() }
                .sorted(by: sortByUsage)

            await MainActor.run { [weak self] in
                self?.materialStats = finalStats
                self?.coOccurrence = coUse
            }
        }
    }

    private func logJobDecodingError(_ error: DecodingError, documentPath: String) {
        let details = describeDecodingError(error)
        let codingPath = details.codingPath.isEmpty ? "<root>" : details.codingPath
        logger.error("Failed to decode document \(documentPath): case=\(details.caseName) codingPath=\(codingPath) debugDescription=\(details.debugDescription)")
    }

    private func describeDecodingError(_ error: DecodingError) -> (caseName: String, codingPath: String, debugDescription: String) {
        switch error {
        case .typeMismatch(let type, let context):
            return (
                caseName: "typeMismatch",
                codingPath: codingPathString(context.codingPath),
                debugDescription: "Expected \(String(describing: type)). \(context.debugDescription)"
            )
        case .valueNotFound(let type, let context):
            return (
                caseName: "valueNotFound",
                codingPath: codingPathString(context.codingPath),
                debugDescription: "Missing \(String(describing: type)). \(context.debugDescription)"
            )
        case .keyNotFound(let key, let context):
            let path = (context.codingPath + [key]).map { $0.stringValue }.joined(separator: ".")
            return (
                caseName: "keyNotFound",
                codingPath: path,
                debugDescription: context.debugDescription
            )
        case .dataCorrupted(let context):
            return (
                caseName: "dataCorrupted",
                codingPath: codingPathString(context.codingPath),
                debugDescription: context.debugDescription
            )
        @unknown default:
            return (
                caseName: "unknown",
                codingPath: "",
                debugDescription: "Unknown decoding error."
            )
        }
    }

    private func codingPathString(_ codingPath: [CodingKey]) -> String {
        codingPath.map { $0.stringValue }.joined(separator: ".")
    }

    nonisolated private func accumulate(_ material: Material, jobType: String, date: Date?, into map: inout [String: MaterialStatsBuilder]) {
        let key = normalize(material.name)
        let builder = map[key, default: MaterialStatsBuilder(key: key, name: material.name)]
        map[key] = builder.add(
            quantity: material.quantity,
            unitCost: material.unitCost,
            unit: material.unit,
            jobType: jobType,
            lastUsed: date
        )
    }

    nonisolated private func trackCoOccurrence(_ names: Set<String>, store: inout [String: [String: Int]]) {
        for primary in names {
            for secondary in names where secondary != primary {
                var inner = store[primary, default: [:]]
                inner[secondary, default: 0] += 1
                store[primary] = inner
            }
        }
    }

    nonisolated private func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated private func sortByUsage(lhs: MaterialUsageStats, rhs: MaterialUsageStats) -> Bool {
        if lhs.totalUsageCount == rhs.totalUsageCount {
            return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
        }
        return lhs.totalUsageCount > rhs.totalUsageCount
    }
}

private struct MaterialStatsBuilder {
    let key: String
    let name: String
    var usageCount: Int = 0
    var totalQuantity: Double = 0
    var totalUnitCost: Double = 0
    var lastUsedAt: Date?
    var jobTypes: [String: Int] = [:]
    var unitCounts: [String: Int] = [:]

    func add(quantity: Double, unitCost: Double, unit: String?, jobType: String, lastUsed: Date?) -> MaterialStatsBuilder {
        var copy = self
        copy.usageCount += 1
        copy.totalQuantity += safeNumber(quantity)
        copy.totalUnitCost += safeNumber(unitCost)
        copy.lastUsedAt = max(copy.lastUsedAt ?? .distantPast, lastUsed ?? .distantPast)

        let trimmedType = jobType.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedType.isEmpty {
            copy.jobTypes[trimmedType, default: 0] += 1
        }

        if let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines), !unit.isEmpty {
            copy.unitCounts[unit, default: 0] += 1
        }

        return copy
    }

    func build() -> MaterialUsageStats {
        let avgQuantity = usageCount > 0 ? safeNumber(totalQuantity / Double(usageCount)) : nil
        let avgUnitCost = usageCount > 0 ? safeNumber(totalUnitCost / Double(usageCount)) : nil
        let mostUsedUnit = unitCounts.max { $0.value < $1.value }?.key

        return MaterialUsageStats(
            key: key,
            name: name,
            totalUsageCount: usageCount,
            averageQuantity: avgQuantity,
            averageUnitCost: avgUnitCost,
            lastUsedAt: lastUsedAt,
            jobTypes: jobTypes,
            mostCommonUnit: mostUsedUnit
        )
    }
}
