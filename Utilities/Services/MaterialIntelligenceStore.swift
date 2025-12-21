import Foundation
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Models

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

// MARK: - Store

@MainActor
final class MaterialIntelligenceStore: ObservableObject {
    @Published private(set) var materialStats: [MaterialUsageStats] = []

    private let db: Firestore
    private var jobsListener: ListenerRegistration?
    private var invoicesListener: ListenerRegistration?
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var resetToken: UUID?
    private var cachedJobs: [Job] = []
    private var cachedInvoices: [Invoice] = []
    private var invalidJobDocumentIDs: Set<String> = []
    private var coOccurrence: [String: [String: Int]] = [:]
    private var loggedDecodingFailures: Set<String> = []

    init(database: Firestore = Firestore.firestore(), session: SessionManager) {
        self.db = database
        self.session = session
        resetToken = session.registerResetHandler { [weak self] in
            self?.clear()
        }
        session.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                self?.setUser(uid)
            }
            .store(in: &cancellables)
        setUser(session.uid)
    }

    deinit {
        Task { @MainActor in
            jobsListener?.remove()
            invoicesListener?.remove()
            cancellables.removeAll()
            if let resetToken {
                session.unregisterResetHandler(resetToken)
            }
        }
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

    // MARK: - Auth / listeners

    private func setUser(_ uid: String?) {
        jobsListener?.remove()
        invoicesListener?.remove()
        materialStats = []
        coOccurrence = [:]
        invalidJobDocumentIDs = []
        cachedJobs = []
        cachedInvoices = []

        guard let uid else { return }

        let jobsPath = "users/\(uid)/jobs"
        print("[Data] MaterialIntelligenceStore uid=\(uid) path=\(jobsPath) action=listen")

        jobsListener = db.collection("users")
            .document(uid)
            .collection("jobs")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { print("Failed to fetch jobs: \(error.localizedDescription)"); return }

                let jobs: [Job] = snapshot?.documents.compactMap { document in
                    if self.invalidJobDocumentIDs.contains(document.documentID) {
                        return nil
                    }

                    guard document.exists else {
                        self.invalidJobDocumentIDs.insert(document.documentID)
                        return nil
                    }

                    guard let job = self.decodeJob(from: document) else {
                        self.invalidJobDocumentIDs.insert(document.documentID)
                        return nil
                    }

                    return job
                } ?? []

                self.cachedJobs = jobs
                self.rebuildStats()
            }

        session.track(jobsListener)

        let invoicesPath = "users/\(uid)/invoices"
        print("[Data] MaterialIntelligenceStore uid=\(uid) path=\(invoicesPath) action=listen")

        invoicesListener = db.collection("users")
            .document(uid)
            .collection("invoices")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { print("Failed to fetch invoices: \(error.localizedDescription)"); return }

                let invoices: [Invoice] = snapshot?.documents.compactMap { document in
                    guard document.exists else { return nil }
                    return self.decodeInvoice(from: document)
                } ?? []

                self.cachedInvoices = invoices
                self.rebuildStats()
            }

        session.track(invoicesListener)
    }

    // MARK: - Stats building

    private func rebuildStats() {
        let jobs = cachedJobs
        let invoices = cachedInvoices

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var statsMap: [String: MaterialStatsBuilder] = [:]
            var coUse: [String: [String: Int]] = [:]

            for job in jobs {
                let materials = job.materials
                let normalizedNames = Set(materials.map { self.normalize($0.name) })

                for material in materials {
                    self.accumulate(material, jobType: job.category, date: job.dateCreated, into: &statsMap)
                }

                self.trackCoOccurrence(normalizedNames, store: &coUse)
            }

            for invoice in invoices {
                let materials = invoice.materials
                let normalizedNames = Set(materials.map { self.normalize($0.name) })
                let timestamp = invoice.dueDate ?? Date()
                let jobType = invoice.title

                for material in materials {
                    self.accumulate(material, jobType: jobType, date: timestamp, into: &statsMap)
                }

                self.trackCoOccurrence(normalizedNames, store: &coUse)
            }

            let finalStats: [MaterialUsageStats] = statsMap.values.map { $0.build() }
                .sorted(by: self.sortByUsage)

            DispatchQueue.main.async {
                self.materialStats = finalStats
                self.coOccurrence = coUse
            }
        }
    }

    private func decodeJob(from document: DocumentSnapshot) -> Job? {
        let documentPath = document.reference.path
        var data = document.data() ?? [:]
        var patch: [String: Any] = [:]
        var missingFields: [String] = []

        if data["id"] == nil {
            let fallbackId = UUID(uuidString: document.documentID)?.uuidString ?? UUID().uuidString
            data["id"] = fallbackId
            patch["id"] = fallbackId
            missingFields.append("id")
        }

        if data["name"] == nil {
            data["name"] = "Untitled Job"
            patch["name"] = "Untitled Job"
            missingFields.append("name")
        }

        if data["category"] == nil {
            data["category"] = "General"
            patch["category"] = "General"
            missingFields.append("category")
        }

        if data["dateCreated"] == nil {
            let fallbackDate = Date()
            data["dateCreated"] = fallbackDate
            patch["dateCreated"] = fallbackDate
            missingFields.append("dateCreated")
        }

        do {
            let job = try Firestore.Decoder().decode(Job.self, from: data)
            if !patch.isEmpty {
                document.reference.setData(patch, merge: true)
            }
            if !missingFields.isEmpty {
                logMissingFields(missingFields, documentPath: documentPath)
            }
            return job
        } catch {
            logDecodingError(error, documentPath: documentPath)
            return nil
        }
    }

    private func decodeInvoice(from document: DocumentSnapshot) -> Invoice? {
        let documentPath = document.reference.path
        var data = document.data() ?? [:]
        var patch: [String: Any] = [:]
        var missingFields: [String] = []

        if data["id"] == nil {
            let fallbackId = UUID(uuidString: document.documentID)?.uuidString ?? UUID().uuidString
            data["id"] = fallbackId
            patch["id"] = fallbackId
            missingFields.append("id")
        }

        if data["invoiceNumber"] == nil {
            let fallbackNumber = InvoiceNumberManager.generateInvoiceNumber(uid: session.uid)
            data["invoiceNumber"] = fallbackNumber
            patch["invoiceNumber"] = fallbackNumber
            missingFields.append("invoiceNumber")
        }

        if data["title"] == nil {
            data["title"] = "Invoice"
            patch["title"] = "Invoice"
            missingFields.append("title")
        }

        if data["clientName"] == nil {
            data["clientName"] = ""
            patch["clientName"] = ""
            missingFields.append("clientName")
        }

        if data["status"] == nil {
            data["status"] = Invoice.InvoiceStatus.draft.rawValue
            patch["status"] = Invoice.InvoiceStatus.draft.rawValue
            missingFields.append("status")
        }

        do {
            let invoice = try Firestore.Decoder().decode(Invoice.self, from: data)
            if !patch.isEmpty {
                document.reference.setData(patch, merge: true)
            }
            if !missingFields.isEmpty {
                logMissingFields(missingFields, documentPath: documentPath)
            }
            return invoice
        } catch {
            logDecodingError(error, documentPath: documentPath)
            return nil
        }
    }

    private func logMissingFields(_ fields: [String], documentPath: String) {
        guard !fields.isEmpty else { return }
        let logKey = "missing:\(documentPath)"
        guard !loggedDecodingFailures.contains(logKey) else { return }
        loggedDecodingFailures.insert(logKey)
        let fieldsString = fields.joined(separator: ", ")
        print("Missing fields in document \(documentPath): \(fieldsString)")
    }

    private func logDecodingError(_ error: Error, documentPath: String) {
        let logKey = "decode:\(documentPath)"
        guard !loggedDecodingFailures.contains(logKey) else { return }
        loggedDecodingFailures.insert(logKey)

        if case DecodingError.keyNotFound(let key, _) = error {
            print("Failed to decode document \(documentPath): missing field \(key.stringValue)")
        } else {
            print("Failed to decode document \(documentPath): \(error.localizedDescription)")
        }
    }

    private func accumulate(_ material: Material, jobType: String, date: Date?, into map: inout [String: MaterialStatsBuilder]) {
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

    private func trackCoOccurrence(_ names: Set<String>, store: inout [String: [String: Int]]) {
        for primary in names {
            for secondary in names where secondary != primary {
                var inner = store[primary, default: [:]]
                inner[secondary, default: 0] += 1
                store[primary] = inner
            }
        }
    }

    private func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func sortByUsage(lhs: MaterialUsageStats, rhs: MaterialUsageStats) -> Bool {
        if lhs.totalUsageCount == rhs.totalUsageCount {
            return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
        }
        return lhs.totalUsageCount > rhs.totalUsageCount
    }

    func clear() {
        jobsListener?.remove()
        invoicesListener?.remove()
        jobsListener = nil
        invoicesListener = nil
        materialStats = []
        coOccurrence = [:]
        cachedJobs = []
        cachedInvoices = []
        invalidJobDocumentIDs = []
    }
}

// MARK: - Builder

private struct MaterialStatsBuilder {
    let key: String
    let name: String
    var usageCount: Int = 0
    var totalQuantity: Double = 0
    var totalUnitCost: Double = 0
    var lastUsedAt: Date?
    var jobTypes: [String: Int] = [:]
    var unitCounts: [String: Int] = [:]

    func add(
        quantity: Double?,          // allow optional in case your model uses optionals
        unitCost: Double?,
        unit: String?,
        jobType: String,
        lastUsed: Date?
    ) -> MaterialStatsBuilder {
        var copy = self
        copy.usageCount += 1
        copy.totalQuantity += safeOptionalNumber(quantity) ?? 0
        copy.totalUnitCost += safeOptionalNumber(unitCost) ?? 0
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
