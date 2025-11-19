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
    }

    func update(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
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
        } catch {
            print("Failed to load jobs: \(error)")
        }
    }
}
