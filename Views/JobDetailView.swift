//
//  JobDetailView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI
import UIKit

struct JobDetailView: View {
    @EnvironmentObject private var vm: JobViewModel
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var companySettings: CompanySettingsStore

    private let jobID: Job.ID
    @State private var job: Job
    @State private var editingMaterialIndex: Int?
    @State private var showingMaterialSheet = false
    @State private var createdInvoice: Invoice?
    @State private var showingInvoiceEditor = false
    @State private var pdfURL: URL?
    @State private var exportError: String?
    @State private var showingPDFPreview = false

    // Labor editor state
    @State private var showingLaborEditor = false
    @State private var laborHoursText = ""
    @State private var laborRateText = ""

    init(job: Job) {
        self.jobID = job.id
        _job = State(initialValue: job)
    }

    var body: some View {
        JobDocumentLayout(
            summary: EstimateSummaryCard(job: job, editLaborAction: showLaborEditor),
            document: EstimateDocumentCard(
                job: job,
                previewAction: previewEstimate,
                convertAction: convertToInvoice
            ),
            customer: { EstimateCustomerCard(client: client(for: job)) },
            quickActions: {
                EstimateQuickActionsCard(
                    client: client(for: job),
                    callAction: callClient,
                    textAction: textClient,
                    followUpAction: followUpClient
                )
            },
            materials: {
                MaterialsSection(
                    materials: job.materials,
                    addAction: {
                        editingMaterialIndex = nil
                        showingMaterialSheet = true
                    },
                    editAction: { index in
                        editingMaterialIndex = index
                        showingMaterialSheet = true
                    },
                    deleteAction: { index in
                        vm.removeMaterial(at: index, in: job)
                    }
                )
            }
        )
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
        .sheet(isPresented: $showingLaborEditor) {
            laborEditorSheet
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let url = pdfURL {
                PDFPreviewSheet(url: url)
            } else {
                Text("No PDF available.")
            }
        }
        .alert("Unable to generate PDF", isPresented: .constant(exportError != nil)) {
            Button("OK", role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "Unknown error")
        }
        .onAppear(perform: syncJobWithViewModel)
        .onReceive(vm.$jobs) { _ in
            syncJobWithViewModel()
        }
    }

    // MARK: - Helpers

    private func client(for job: Job) -> Client? {
        guard let clientId = job.clientId else { return nil }
        return clientVM.clients.first(where: { $0.id == clientId })
    }

    private func showLaborEditor() {
        laborHoursText = String(format: "%.2f", job.laborHours)
        laborRateText = String(format: "%.2f", job.laborRate)
        showingLaborEditor = true
    }

    // MARK: - Materials editing

    private func saveLabor() {
        let hoursString = laborHoursText.replacingOccurrences(of: ",", with: ".")
        let rateString = laborRateText.replacingOccurrences(of: ",", with: ".")

        guard let hours = Double(hoursString),
              let rate = Double(rateString) else {
            showingLaborEditor = false
            return
        }

        var updated = job
        updated.laborHours = hours
        updated.laborRate = rate

        vm.update(updated)
        job = updated
        showingLaborEditor = false
    }

    private func syncJobWithViewModel() {
        guard let updatedJob = vm.jobs.first(where: { $0.id == jobID }) else { return }
        job = updatedJob
    }

    private func previewEstimate() {
        exportError = nil
        do {
            let url = try InvoicePDFRenderer.generateInvoicePDF(
                for: job,
                client: client(for: job),
                company: companySettings.settings
            )
            pdfURL = url
            showingPDFPreview = true
        } catch {
            exportError = error.localizedDescription
            print("Failed to generate invoice PDF:", error)
        }
    }

    private func convertToInvoice() {
        let clientName = clientVM.clients.first(where: { $0.id == job.clientId })?.name ?? "Unassigned"

        // Start with the existing materials from the estimate
        var invoiceMaterials = job.materials

        // If there is labor, add it as a separate line item
        if job.laborHours > 0 && job.laborRate > 0 {
            let laborMaterial = Material(
                id: UUID(),
                name: "Labor",
                quantity: job.laborHours,
                unitCost: job.laborRate
                // add any extra Material fields you have (notes/url/etc) with sensible defaults
            )
            invoiceMaterials.append(laborMaterial)
        }

        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: InvoiceNumberManager.shared.generateInvoiceNumber(),
            title: job.name,
            clientID: job.clientId,
            clientName: clientName,
            materials: invoiceMaterials,
            status: .draft,
            dueDate: nil
        )

        invoiceVM.add(invoice)
        vm.delete(job)
        createdInvoice = invoice
        showingInvoiceEditor = true
    }

    // MARK: - Quick Actions

    private func callClient() {
        guard
            let phone = client(for: job)?.phone,
            !phone.isEmpty
        else { return }

        // keep only digits for the tel:// URL
        let digits = phone.filter("0123456789".contains)

        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func textClient() {
        guard
            let phone = client(for: job)?.phone,
            !phone.isEmpty
        else { return }

        let digits = phone.filter("0123456789".contains)

        guard let url = URL(string: "sms:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func followUpClient() {
        guard
            let email = client(for: job)?.email,
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
    let job: Job
    let previewAction: () -> Void
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
                        Label("Preview Invoice", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(PrimaryBlueButton())

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
                        Text(client?.company.isEmpty == false ? client?.company ?? "—" : "Not Assigned")
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
                    ForEach(Array(materials.enumerated()), id: \.element.id) { index, material in
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
                        .contextMenu {
                            Button("Edit") {
                                editAction(index)
                            }

                            Button(role: .destructive) {
                                deleteAction(index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if material.id != materials.last?.id {
                            Divider().overlay(Color.white.opacity(0.15))
                        }
                    }
                }
            }
        }
    }
}

