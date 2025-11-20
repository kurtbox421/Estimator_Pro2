//
//  JobViewModel.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import Foundation

private let jobsStorageKey = "EstimatorPro_Jobs"

class JobViewModel: ObservableObject {
    @Published var jobs: [Job] = [] {
        didSet {
            saveJobs()
        }
    }

    init() {
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
        do {
            let data = try JSONEncoder().encode(jobs)
            UserDefaults.standard.set(data, forKey: jobsStorageKey)
        } catch {
            print("Failed to save jobs: \(error)")
        }
    }

    private func loadJobs() {
        guard let data = UserDefaults.standard.data(forKey: jobsStorageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([Job].self, from: data)
            jobs = decoded
            sortJobs()
        } catch {
            print("Failed to load jobs: \(error)")
        }
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
