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
        jobs.append(job)
        sortJobs()
    }

    func update(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
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

        var updatedJob = job
        updatedJob.materials[index] = material
        jobs[jobIndex] = updatedJob
        sortJobs()
    }

    func addMaterial(_ material: Material, to job: Job) {
        guard let jobIndex = jobs.firstIndex(where: { $0.id == job.id }) else { return }

        var updatedJob = job
        updatedJob.materials.append(material)
        jobs[jobIndex] = updatedJob
        sortJobs()
    }

    func removeMaterial(at index: Int, in job: Job) {
        guard let jobIndex = jobs.firstIndex(where: { $0.id == job.id }),
              jobs[jobIndex].materials.indices.contains(index) else { return }

        var updatedJob = job
        updatedJob.materials.remove(at: index)
        jobs[jobIndex] = updatedJob
        sortJobs()
    }

    func jobs(for client: Client) -> [Job] {
        jobs.filter { $0.clientId == client.id }
    }

    func jobCount(for client: Client) -> Int {
        jobs(for: client).count
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

        if let migrated: [Job] = persistence.migrateFromUserDefaults(key: JobStorage.userDefaultsKey, fileName: JobStorage.fileName, as: [Job].self) {
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
}
