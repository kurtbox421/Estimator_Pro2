//
//  JobDetailView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//
import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject private var vm: JobViewModel
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    @EnvironmentObject private var clientVM: ClientViewModel

    private let jobID: Job.ID
    @State private var job: Job
    @State private var editingMaterialIndex: Int?
    @State private var showingMaterialSheet = false
    @State private var createdInvoice: Invoice?
    @State private var showingInvoiceEditor = false

    init(job: Job) {
        self.jobID = job.id
        _job = State(initialValue: job)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    materialsCard
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMaterialSheet) {
            if let index = editingMaterialIndex {
                AddMaterialView(
                    mode: .edit(job: job, index: index),
                    jobVM: vm,
                    invoiceVM: invoiceVM
                )
            } else {
                AddMaterialView(
                    mode: .add(job: job),
                    jobVM: vm,
                    invoiceVM: invoiceVM
                )
            }
        }
        .sheet(isPresented: $showingInvoiceEditor) {
            if let createdInvoice {
                NavigationView {
                    AddEditInvoiceView(mode: .edit(createdInvoice))
                        .environmentObject(invoiceVM)
                        .environmentObject(clientVM)
                }
            }
        }
        .onAppear(perform: syncJobWithViewModel)
        .onReceive(vm.$jobs) { _ in
            syncJobWithViewModel()
        }
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.18, blue: 0.32),
                Color(red: 0.05, green: 0.30, blue: 0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var cardBackground: some View {
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
    }

    private var summaryCard: some View {
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
                    Text(job.laborCost.formatted(.currency(code: "USD")))
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Materials")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(job.materialCost.formatted(.currency(code: "USD")))
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(job.total.formatted(.currency(code: "USD")))
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                }
            }

            Button(action: convertToInvoice) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .imageScale(.medium)
                    Text("Convert to Invoice")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.85),
                            Color.pink.opacity(0.75)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .padding(.horizontal, 24)
    }

    private var materialsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            materialsList
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .padding(.horizontal, 24)
    }

    private var headerRow: some View {
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
                editingMaterialIndex = nil
                showingMaterialSheet = true
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
    }

    private var materialsList: some View {
        Group {
            if job.materials.isEmpty {
                Text("No materials added yet. Use the Add button to start building your estimate.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            } else {
                ForEach(job.materials.indices, id: \.self) { index in
                    materialRow(for: index)
                    Divider().background(Color.white.opacity(0.15))
                }
            }
        }
    }

    private func materialRow(for index: Int) -> some View {
        let material = job.materials[index]

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(material.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Text("\(String(format: "%.2f", material.quantity)) × \(material.unitCost.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            Text(material.cost.formatted(.currency(code: "USD")))
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Edit") {
                editingMaterialIndex = index
                showingMaterialSheet = true
            }
            .tint(.blue)

            Button(role: .destructive) {
                vm.removeMaterial(at: index, in: job)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Logic

    private func syncJobWithViewModel() {
        guard let updatedJob = vm.jobs.first(where: { $0.id == jobID }) else { return }
        job = updatedJob
    }

    private func convertToInvoice() {
        let clientName = clientVM.clients.first(where: { $0.id == job.clientId })?.name ?? "Unassigned"

        let invoice = Invoice(
            id: UUID(),
            title: job.name,
            clientID: job.clientId,
            clientName: clientName,
            materials: job.materials,
            status: .draft,
            dueDate: nil
        )

        invoiceVM.add(invoice)
        createdInvoice = invoice
        showingInvoiceEditor = true
    }
}
