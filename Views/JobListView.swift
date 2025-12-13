//
//  JobListView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

struct JobListView: View {
    @EnvironmentObject private var vm: JobViewModel
    @State private var adding = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Theme.gradientStart, Theme.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Estimator Pro")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    Text("Jobs & Estimates")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    // Card-style list
                    List {
                        ForEach(vm.jobs) { job in
                            NavigationLink(destination: JobDetailView(estimate: binding(for: job))) {
                                JobRowView(job: job)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: vm.delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $adding) {
                NavigationView {
                    AddEditJobView(mode: .add)
                }
            }
        }
    }

    private func binding(for job: Job) -> Binding<Job> {
        guard let index = vm.jobs.firstIndex(where: { $0.id == job.id }) else {
            return .constant(job)
        }

        return $vm.jobs[index]
    }
}

/// Card row for each job
struct JobRowView: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.name)
                    .font(.headline)
                    .foregroundColor(Theme.primaryText)

                Spacer()

                Text("$\(job.total, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            HStack {
                Label(job.category, systemImage: "folder.fill")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)

                Spacer()

                Text(job.dateCreated, style: .date)
                    .font(.caption)
                    .foregroundColor(Theme.secondaryText)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

