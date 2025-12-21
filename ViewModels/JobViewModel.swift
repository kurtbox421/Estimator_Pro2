//
//  JobViewModel.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation
import Combine
import FirebaseFirestore

private enum JobStorage {
    static func fileName(for uid: String) -> String { "jobs_\(uid).json" }
}

class JobViewModel: ObservableObject {
    @Published var jobs: [Job] = [] {
        didSet { saveJobs() }
    }

    private let persistence: PersistenceService
    private let db: Firestore
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var resetToken: UUID?
    private var currentUserID: String?

    init(
        persistence: PersistenceService = .shared,
        database: Firestore = Firestore.firestore(),
        session: SessionManager
    ) {
        self.persistence = persistence
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
        if let resetToken {
            session.unregisterResetHandler(resetToken)
        }
    }
    
    // MARK: - CRUD
    
    func add(_ job: Job) {
        var newJob = job
        recalculateTotals(for: &newJob)
        jobs.append(newJob)
        sortJobs()
    }
    
    func update(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            var updated = job
            recalculateTotals(for: &updated)
            jobs[index] = updated
            sortJobs()
        }
    }
    
    func delete(at offsets: IndexSet) {
        jobs.remove(atOffsets: offsets)
    }

    func delete(_ job: Job) {
        delete(jobID: job.id)
    }

    func delete(jobID: Job.ID) {
        let countBeforeDelete = jobs.count

        #if DEBUG
        print("[JobViewModel] delete(jobID:) before: \(countBeforeDelete) items")
        #endif

        jobs.removeAll { $0.id == jobID }

        #if DEBUG
        let countAfterDelete = jobs.count
        print("[JobViewModel] delete(jobID:) after: \(countAfterDelete) items")
        #endif
    }

    func assignClient(jobID: Job.ID, to clientID: Client.ID) {
        guard let uid = currentUserID else { return }

        guard let jobIndex = jobs.firstIndex(where: { $0.id == jobID }) else { return }

        var updatedJob = jobs[jobIndex]
        updatedJob.clientId = clientID
        jobs[jobIndex] = updatedJob
        sortJobs()

        let path = "users/\(uid)/jobs/\(jobID.uuidString)"
        print("[Data] JobViewModel uid=\(uid) path=\(path) action=write")

        db.collection("users")
            .document(uid)
            .collection("jobs")
            .document(jobID.uuidString)
            .setData(["clientId": clientID.uuidString], merge: true)
    }

    func update(_ job: Job, replacingMaterialAt index: Int, with material: Material) {
        guard let jobIndex = jobs.firstIndex(where: { $0.id == job.id }),
              jobs[jobIndex].materials.indices.contains(index) else { return }
        
        var updatedJob = jobs[jobIndex]
        updatedJob.materials[index] = material
        recalculateTotals(for: &updatedJob)
        jobs[jobIndex] = updatedJob
        sortJobs()
    }
    
    func addMaterial(_ material: Material, to job: Job) {
        guard let jobIndex = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        
        var updatedJob = jobs[jobIndex]
        updatedJob.materials.append(material)
        recalculateTotals(for: &updatedJob)
        jobs[jobIndex] = updatedJob
        sortJobs()
    }
    
    func removeMaterial(at index: Int, in job: Job) {
        guard let jobIndex = jobs.firstIndex(where: { $0.id == job.id }),
              jobs[jobIndex].materials.indices.contains(index) else { return }

        var updatedJob = jobs[jobIndex]
        updatedJob.materials.remove(at: index)
        recalculateTotals(for: &updatedJob)
        jobs[jobIndex] = updatedJob
        sortJobs()
    }

    func appendMaterials(_ materials: [Material], to jobID: Job.ID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }

        var updatedJob = jobs[index]
        updatedJob.materials.append(contentsOf: materials)
        recalculateTotals(for: &updatedJob)
        jobs[index] = updatedJob
        sortJobs()
    }

    /// Creates and saves a new estimate pre-populated with materials.
    @discardableResult
    func createEstimate(from materials: [Material], jobType: MaterialJobType?) -> Job {
        let displayName = jobType?.displayName ?? "New Estimate"

        var job = Job(
            name: displayName,
            category: displayName,
            laborLines: [],
            materials: materials,
            clientId: nil
        )

        recalculateTotals(for: &job)
        jobs.append(job)
        sortJobs()
        return job
    }
    
    func jobs(for client: Client) -> [Job] {
        jobs.filter { $0.clientId == client.id }
    }

    func job(for id: Job.ID) -> Job? {
        jobs.first(where: { $0.id == id })
    }
    
    func jobCount(for client: Client) -> Int {
        jobs(for: client).count
    }
    
    // MARK: - Generated materials
    
    /// Apply AI-/rule-generated materials to an existing job.
    func applyGeneratedMaterials(_ generated: [SuggestedMaterial], to job: Job?) {
        guard let job,
              !generated.isEmpty,
              let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }

        let ownerID = currentUserID ?? ""

        let newMaterials: [Material] = generated.map { gm in
            Material(
                id: UUID(),
                ownerID: ownerID,
                name: gm.name,
                quantity: gm.quantity,
                unitCost: gm.unitCost
                // add other Material fields here if you have them (e.g. notes, url)
            )
        }
        
        var updatedJob = jobs[index]
        updatedJob.materials.append(contentsOf: newMaterials)
        recalculateTotals(for: &updatedJob)
        jobs[index] = updatedJob
        sortJobs()
    }
    
    // MARK: - Persistence
    
    private func saveJobs() {
        guard let uid = currentUserID else { return }
        print("[Data] JobViewModel uid=\(uid) path=local:\(JobStorage.fileName(for: uid)) action=save")
        persistence.save(jobs, to: JobStorage.fileName(for: uid))
    }

    private func loadJobs(for uid: String) {
        print("[Data] JobViewModel uid=\(uid) path=local:\(JobStorage.fileName(for: uid)) action=load")
        if let stored: [Job] = persistence.load([Job].self, from: JobStorage.fileName(for: uid)) {
            jobs = stored
            sortJobs()
            return
        }

        jobs = []
    }

    private func setUser(_ uid: String?) {
        currentUserID = uid
        jobs = []

        guard let uid else { return }

        loadJobs(for: uid)
    }
    
    private func sortJobs() {
        jobs.sort { lhs, rhs in
            if lhs.dateCreated != rhs.dateCreated {
                return lhs.dateCreated > rhs.dateCreated
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    // MARK: - Totals
    
    /// If `Job` used stored properties for materialCost/total we would update them here.
    /// Currently they are computed properties, so there's nothing to assign.
    private func recalculateTotals(for job: inout Job) {
        // no-op
    }

    func clear() {
        currentUserID = nil
        jobs = []
    }
}
