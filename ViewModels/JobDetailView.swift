//
//  JobDetailView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject private var vm: JobViewModel

    @State private var job: Job
    @State private var showingAddMaterial = false

    init(job: Job) {
        _job = State(initialValue: job)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.18, blue: 0.32),
                    Color(red: 0.05, green: 0.30, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // SUMMARY CARD
                    VStack(alignment: .leading, spacing: 12) {
                        Text(job.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text(job.category)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Divider().background(Color.white.opacity(0.2))

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Labor")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("$\(job.laborCost, specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Materials")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("$\(job.materialCost, specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("$\(job.total, specifier: "%.2f")")
                                    .font(.title3.bold())
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .background(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.02),
                                                Color.black.opacity(0.40)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    // MATERIALS CARD
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Materials")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(job.materials.count) items")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Button {
                                showingAddMaterial = true
                            } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.caption.bold())
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.16))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white)
                            }
                        }

                        if job.materials.isEmpty {
                            Text("No materials added yet. Use the Add button to start building your estimate.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.75))
                        } else {
                            ForEach(job.materials) { material in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(material.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                        Text("\(material.quantity, specifier: "%.2f") × $\(material.unitCost, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.75))
                                    }

                                    Spacer()

                                    Text("$\(material.cost, specifier: "%.2f")")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 6)

                                Divider().background(Color.white.opacity(0.15))
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .background(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.02),
                                                Color.black.opacity(0.40)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddMaterial) {
            AddMaterialView { newMaterial in
                job.materials.append(newMaterial)
                vm.update(job)
            }
        }
    }
}
