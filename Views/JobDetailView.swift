//
//  JobDetailView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject private var vm: JobViewModel

    private let jobID: Job.ID
    @State private var job: Job
    @State private var showingAddMaterial = false
    @State private var editingMaterial: Material?

    init(job: Job) {
        jobID = job.id
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingMaterial = material
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editingMaterial = material
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteMaterial(material)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

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
        .sheet(item: $editingMaterial) { material in
            MaterialEditorView(material: material) { updatedMaterial in
                updateMaterial(updatedMaterial)
            }
        }
        .onAppear(perform: syncJobWithViewModel)
        .onReceive(vm.$jobs) { _ in
            syncJobWithViewModel()
        }
    }

    private func deleteMaterial(_ material: Material) {
        guard let index = job.materials.firstIndex(where: { $0.id == material.id }) else { return }
        job.materials.remove(at: index)
        vm.update(job)
    }

    private func updateMaterial(_ material: Material) {
        guard let index = job.materials.firstIndex(where: { $0.id == material.id }) else { return }
        job.materials[index] = material
        vm.update(job)
    }

    private func syncJobWithViewModel() {
        guard let updatedJob = vm.jobs.first(where: { $0.id == jobID }) else { return }
        job = updatedJob
    }
}

private struct MaterialEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var material: Material
    var onSave: (Material) -> Void

    @State private var name: String
    @State private var quantity: String
    @State private var unitCost: String

    init(material: Material, onSave: @escaping (Material) -> Void) {
        self.material = material
        self.onSave = onSave
        _name = State(initialValue: material.name)
        _quantity = State(initialValue: String(material.quantity))
        _unitCost = State(initialValue: String(material.unitCost))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Material")) {
                    TextField("Name", text: $name)
                }

                Section(header: Text("Details")) {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Unit cost", text: $unitCost)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(quantity) != nil &&
        Double(unitCost) != nil
    }

    private func save() {
        guard let q = Double(quantity),
              let u = Double(unitCost)
        else { return }

        let updatedMaterial = Material(
            id: material.id,
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: q,
            unitCost: u
        )

        onSave(updatedMaterial)
        dismiss()
    }
}
