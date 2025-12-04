//
//  JobViewModel.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation

private enum JobStorage {
    static let userDefaultsKey = "EstimatorPro_Jobs"
    static let fileName = "jobs.json"
}

class JobViewModel: ObservableObject {
    @Published var jobs: [Job] = [] {
        didSet {
            saveJobs()
        }
    }
    
    private let persistence: PersistenceService
    
    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        loadJobs()
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
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs.remove(at: index)
        }
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
            laborHours: 0,
            laborRate: 0,
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
    
    func jobCount(for client: Client) -> Int {
        jobs(for: client).count
    }
    
    // MARK: - Generated materials
    
    /// Apply AI-/rule-generated materials to an existing job.
    func applyGeneratedMaterials(_ generated: [SuggestedMaterial], to job: Job?) {
        guard let job,
              !generated.isEmpty,
              let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        
        let newMaterials: [Material] = generated.map { gm in
            Material(
                id: UUID(),
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
        persistence.save(jobs, to: JobStorage.fileName)
    }
    
    private func loadJobs() {
        if let stored: [Job] = persistence.load([Job].self, from: JobStorage.fileName) {
            jobs = stored
            sortJobs()
            return
        }
        
        if let migrated: [Job] = persistence.migrateFromUserDefaults(
            key: JobStorage.userDefaultsKey,
            fileName: JobStorage.fileName,
            as: [Job].self
        ) {
            jobs = migrated
            sortJobs()
            return
        }
        
        jobs = []
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
}
