//
//  JobDetailView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI
import UIKit

struct EstimateDetailView: View {
    @EnvironmentObject private var vm: JobViewModel
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    @EnvironmentObject private var estimateVM: EstimateViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var companySettings: CompanySettingsStore

    @Binding var estimate: Job
    @State private var createdInvoice: Invoice?
    @State private var showingInvoiceEditor = false
    @State private var showingMaterialManager = false

    // Labor editor state
    @State private var showingLaborEditor = false
    @State private var laborHoursText = ""
    @State private var laborRateText = ""

    // Material editor state
    @State private var showingMaterialEditor = false

    var body: some View {
        JobDocumentLayout(
            summary: VStack(spacing: 12) {
                EstimateSummaryCard(job: estimate, editLaborAction: showLaborEditor)
            },
            document: EstimateDocumentCard(
                estimate: estimate,
                previewAction: previewEstimate,
                editAction: editEstimate,
                convertAction: convertToInvoice
            ),
            customer: { EstimateCustomerCard(client: client(for: estimate)) },
            quickActions: {
                EstimateQuickActionsCard(
                    client: client(for: estimate),
                    callAction: callClient,
                    textAction: textClient,
                    followUpAction: followUpClient
                )
            },
            materials: {
                RoundedCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Materials")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                Text("\(estimate.materials.count) items")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            Button(action: addMaterial) {
                                Label("Add Material", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.16))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white)
                            }
                        }

                        if estimate.materials.isEmpty {
                            Text("No materials added yet.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            ForEach($estimate.materials) { $material in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            TextField("Description", text: $material.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.white)

                                            Text("\(material.quantity, specifier: "%.2f") × \(material.unitCost, format: .currency(code: "USD"))")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }

                                        Spacer()

                                        Text(material.total, format: .currency(code: "USD"))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.vertical, 6)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteMaterial(material)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                                if material.id != estimate.materials.last?.id {
                                    Divider().overlay(Color.white.opacity(0.15))
                                }
                            }
                        }
                    }
                }
            }
        )
        .navigationTitle("Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInvoiceEditor) {
            if let createdInvoice {
                NavigationView {
                    AddEditInvoiceView(mode: .edit(createdInvoice))
                        .environmentObject(invoiceVM)
                        .environmentObject(clientVM)
                }
            }
        }
        .sheet(isPresented: $showingMaterialManager) {
            MaterialManagerSheet(
                job: $estimate,
                jobVM: vm,
                invoiceVM: invoiceVM
            )
        }
        .sheet(isPresented: $showingLaborEditor) {
            laborEditorSheet
        }
        .sheet(isPresented: $showingMaterialEditor) {
            AddMaterialView(
                mode: .add(job: estimate),
                jobVM: vm,
                invoiceVM: invoiceVM
            )
        }
        .sheet(isPresented: Binding(
            get: { estimateVM.isShowingPreview },
            set: { estimateVM.isShowingPreview = $0 }
        )) {
            if let url = estimateVM.previewURL {
                PDFPreviewSheet(url: url)
            } else {
                Text("No PDF available.")
            }
        }
        .alert("Unable to generate PDF", isPresented: Binding(
            get: { estimateVM.previewError != nil },
            set: { if !$0 { estimateVM.previewError = nil } }
        )) {
            Button("OK", role: .cancel) {
                estimateVM.previewError = nil
            }
        } message: {
            Text(estimateVM.previewError ?? "Unknown error")
        }
    }

    // MARK: - Helpers

    private func client(for job: Job) -> Client? {
        guard let clientId = job.clientId else { return nil }
        return clientVM.clients.first(where: { $0.id == clientId })
    }

    private func showLaborEditor() {
        laborHoursText = String(format: "%.2f", estimate.laborHours)
        laborRateText = String(format: "%.2f", estimate.laborRate)
        showingLaborEditor = true
    }

    // MARK: - Materials editing

    private func addMaterial() {
        showingMaterialEditor = true
    }

    private func deleteMaterial(_ material: Material) {
        if let index = estimate.materials.firstIndex(where: { $0.id == material.id }) {
            estimate.materials.remove(at: index)
            vm.update(estimate)
        }
    }

    private func saveLabor() {
        let hoursString = laborHoursText.replacingOccurrences(of: ",", with: ".")
        let rateString = laborRateText.replacingOccurrences(of: ",", with: ".")

        guard let hours = Double(hoursString),
              let rate = Double(rateString) else {
            showingLaborEditor = false
            return
        }

        estimate.laborHours = hours
        estimate.laborRate = rate

        vm.update(estimate)
        showingLaborEditor = false
    }

    private func previewEstimate() {
        estimateVM.preview(
            estimate: estimate,
            client: client(for: estimate),
            company: companySettings.settings
        )
    }

    private func editEstimate() {
        showingMaterialManager = true
    }

    private func convertToInvoice() {
        let clientName = clientVM.clients.first(where: { $0.id == estimate.clientId })?.name ?? "Unassigned"

        // Start with the existing materials from the estimate
        var invoiceMaterials = estimate.materials

        // If there is labor, add it as a separate line item
        if estimate.laborHours > 0 && estimate.laborRate > 0 {
            let laborMaterial = Material(
                id: UUID(),
                name: "Labor",
                quantity: estimate.laborHours,
                unitCost: estimate.laborRate
                // add any extra Material fields you have (notes/url/etc) with sensible defaults
            )
            invoiceMaterials.append(laborMaterial)
        }

        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: InvoiceNumberManager.shared.generateInvoiceNumber(),
            title: estimate.name,
            clientID: estimate.clientId,
            clientName: clientName,
            materials: invoiceMaterials,
            status: .draft,
            dueDate: nil
        )

        invoiceVM.add(invoice)
        vm.delete(estimate)
        createdInvoice = invoice
        showingInvoiceEditor = true
    }

    // MARK: - Quick Actions

    private func callClient() {
        guard
            let phone = client(for: estimate)?.phone,
            !phone.isEmpty
        else { return }

        // keep only digits for the tel:// URL
        let digits = phone.filter("0123456789".contains)

        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func textClient() {
        guard
            let phone = client(for: estimate)?.phone,
            !phone.isEmpty
        else { return }

        let digits = phone.filter("0123456789".contains)

        guard let url = URL(string: "sms:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func followUpClient() {
        guard
            let email = client(for: estimate)?.email,
            !email.isEmpty,
            let url = URL(string: "mailto:\(email)")
        else { return }

        UIApplication.shared.open(url)
    }

    // MARK: - Labor editor sheet

    private var laborEditorSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Labor details")) {
                    TextField("Hours", text: $laborHoursText)
                        .keyboardType(.decimalPad)
                    TextField("Rate per hour", text: $laborRateText)
                        .keyboardType(.decimalPad)
                    if let hours = Double(laborHoursText.replacingOccurrences(of: ",", with: ".")),
                       let rate = Double(laborRateText.replacingOccurrences(of: ",", with: ".")) {
                        let cost = hours * rate
                        Text("Labor cost: \(cost.formatted(.currency(code: "USD")))")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit labor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingLaborEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLabor()
                    }
                }
            }
        }
    }
}

// MARK: - Cards

private struct EstimateSummaryCard: View {
    let job: Job
    let editLaborAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if !job.category.isEmpty {
                            Text(job.category)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        HStack(spacing: 8) {
                            Label("Estimate", systemImage: "doc.text")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                )
                                .foregroundColor(.white)

                            Button(action: editLaborAction) {
                                Label("Edit Labor", systemImage: "wrench.and.screwdriver")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.16))
                            )
                            .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        Text("\(job.materials.count)")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Materials")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))

                        Divider().background(Color.white.opacity(0.2))

                        Text("0")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Tools")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                }

                HStack {
                    Text(job.total.formatted(.currency(code: "USD")))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EstimateDocumentCard: View {
    let estimate: Job?
    let previewAction: () -> Void
    let editAction: () -> Void
    let convertAction: () -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Document")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                Text("Estimate")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                Text("This job is currently an estimate. Convert it to an invoice when the client is ready to move forward.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 12) {
                    Button(action: previewAction) {
                        Label("Preview Estimate", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(PrimaryBlueButton())
                    .disabled(estimate == nil)

                    Button(action: editAction) {
                        Label("Edit Estimate", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(PrimaryBlueButton())
                    .disabled(estimate == nil)

                    Button(action: convertAction) {
                        Label("Convert to Invoice", systemImage: "doc.richtext")
                    }
                    .buttonStyle(PrimaryBlueButton())
                }
            }
        }
    }
}

struct EstimateCustomerCard: View {
    let client: Client?

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Customer")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        customerLabel("Client")
                        customerLabel("Name")
                        customerLabel("Address")
                        customerLabel("Phone")
                        customerLabel("Email")
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Text(clientDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text(client?.name ?? "—")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text(client?.address ?? "—")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text(client?.phone ?? "—")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text(client?.email ?? "—")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func customerLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.7))
    }
}

extension EstimateCustomerCard {
    private var clientDisplayName: String {
        guard let client else { return "Not Assigned" }

        if client.company.isEmpty == false {
            return client.company
        }

        if client.name.isEmpty == false {
            return client.name
        }

        return "Not Assigned"
    }
}

struct EstimateQuickActionsCard: View {
    let client: Client?
    let callAction: () -> Void
    let textAction: () -> Void
    let followUpAction: () -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                Button(action: callAction) {
                    Label("Call \(client?.name.split(separator: " ").first.map(String.init) ?? "Client")", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GreenActionButton())

                HStack(spacing: 12) {
                    Button(action: textAction) {
                        Label("Text", systemImage: "text.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryPillButton())

                    Button(action: followUpAction) {
                        Label("Send Follow-up", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryPillButton())
                }
            }
        }
    }
}

struct EditDocumentCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Button(action: action) {
                    Label(buttonTitle, systemImage: "square.and.pencil")
                }
                .buttonStyle(PrimaryBlueButton())
            }
        }
    }
}

struct MaterialManagerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var job: Job
    @ObservedObject var jobVM: JobViewModel
    @ObservedObject var invoiceVM: InvoiceViewModel

    @State private var editorMode: AddMaterialView.Mode?

    var body: some View {
        NavigationView {
            List {
                if job.materials.isEmpty {
                    Text("No materials added yet.")
                        .foregroundColor(.secondary)
                } else {
                    Section(header: Text("Materials")) {
                        ForEach(job.materials.indices, id: \.self) { index in
                            let material = job.materials[index]

                            VStack(alignment: .leading, spacing: 4) {
                                Text(material.name)
                                    .font(.headline)
                                Text("\(material.quantity, specifier: "%.2f") × \(material.unitCost, format: .currency(code: "USD"))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(material.cost, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editorMode = .edit(job: job, index: index)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    deleteMaterial(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Materials")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorMode = .add(job: job)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            AddMaterialView(mode: mode, jobVM: jobVM, invoiceVM: invoiceVM)
        }
    }

    private func deleteMaterial(at index: Int) {
        guard job.materials.indices.contains(index) else { return }
        job.materials.remove(at: index)
        jobVM.update(job)
    }
}

struct MaterialsSection: View {
    let materials: [Material]
    let addAction: () -> Void
    let editAction: (Int) -> Void
    let deleteAction: (Int) -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Materials")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(materials.count) items")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Button(action: addAction) {
                        Label("Add", systemImage: "plus")
                            .font(.caption.bold())
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                    }
                }

                if materials.isEmpty {
                    Text("No materials added yet.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    let lastIndex = materials.indices.last

                    ForEach(materials.indices, id: \.self) { index in
                        let material = materials[index]

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(material.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("\(String(format: "%.2f", material.quantity)) × \(material.unitCost.formatted(.currency(code: "USD")))")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(material.cost.formatted(.currency(code: "USD")))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editAction(index)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                deleteAction(index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if let lastIndex, index != lastIndex {
                            Divider().overlay(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }
}

