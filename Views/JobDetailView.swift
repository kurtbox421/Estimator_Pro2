//
//  JobDetailView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI
import UIKit
import FirebaseAuth

struct JobDetailView: View {
    @EnvironmentObject private var vm: JobViewModel
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    @EnvironmentObject private var estimateVM: EstimateViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var companySettings: CompanySettingsStore
    @EnvironmentObject private var emailTemplateSettings: EmailTemplateSettingsStore

    @Binding var estimate: Job
    @State private var createdInvoice: Invoice?
    @State private var showingInvoiceEditor = false
    @State private var showingMaterialManager = false
    @State private var isShowingClientPicker = false
    @State private var clientSearchText = ""
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareError: String?

    // Material editor state
    @State private var showingMaterialEditor = false

    var body: some View {
        jobLayout
            .navigationTitle("Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingInvoiceEditor) { invoiceEditor }
            .sheet(isPresented: $showingMaterialManager) { materialManagerSheet }
            .sheet(isPresented: $showingMaterialEditor) { materialEditorSheet }
            .sheet(isPresented: $isShowingClientPicker) { clientPickerSheet }
            .sheet(isPresented: previewSheetBinding) { previewSheet }
            .alert("Unable to generate PDF", isPresented: previewErrorBinding) {
                previewErrorActions
            } message: {
                previewErrorMessage
            }
            .alert("Unable to share PDF", isPresented: shareErrorBinding) {
                shareErrorActions
            } message: {
                shareErrorMessage
            }
            .sheet(isPresented: $isShowingShareSheet) { ShareSheet(activityItems: shareItems) }
            .onChange(of: estimate.laborLines) { _ in vm.update(estimate) }
    }

    private var jobLayout: some View {
        JobDocumentLayout(
            summary: summarySection,
            document: documentSection,
            customer: { customerSection },
            quickActions: { quickActionsSection },
            materials: { materialsSection }
        )
    }

    @ViewBuilder
    private var invoiceEditor: some View {
        if let createdInvoice {
            NavigationView {
                AddEditInvoiceView(mode: .edit(createdInvoice))
                    .environmentObject(invoiceVM)
                    .environmentObject(clientVM)
            }
        }
    }

    private var materialManagerSheet: some View {
        MaterialManagerSheet(
            job: $estimate,
            jobVM: vm,
            invoiceVM: invoiceVM
        )
    }

    private var materialEditorSheet: some View {
        AddMaterialView(
            mode: .add(job: estimate),
            jobVM: vm,
            invoiceVM: invoiceVM
        )
    }

    @ViewBuilder
    private var clientPickerSheet: some View {
        NavigationView {
            List {
                ForEach(filteredClients) { client in
                    Button { assignClient(client) } label: {
                        clientRow(for: client)
                    }
                }
            }
            .searchable(text: $clientSearchText)
            .navigationTitle("Assign Client")
            .toolbar { clientPickerToolbar }
        }
    }

    @ViewBuilder
    private var previewSheet: some View {
        if let url = estimateVM.previewURL {
            PDFPreviewSheet(url: url)
        } else {
            Text("No PDF available.")
        }
    }

    private var previewErrorActions: some View {
        Button("OK", role: .cancel) { estimateVM.previewError = nil }
    }

    private var previewErrorMessage: some View {
        Text(estimateVM.previewError ?? "Unknown error")
    }

    private var shareErrorActions: some View {
        Button("OK", role: .cancel) { shareError = nil }
    }

    private var shareErrorMessage: some View {
        Text(shareError ?? "Unknown error")
    }

    private var currentClient: Client? {
        client(for: estimate)
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(spacing: 12) {
            EstimateSummaryCard(job: estimate, editLaborAction: addLaborLine)
        }
    }

    private var documentSection: some View {
        EstimateDocumentCard(
            estimate: estimate,
            previewAction: previewEstimate,
            shareAction: shareEstimatePDF,
            editAction: editEstimate,
            convertAction: convertToInvoice
        )
    }

    private var customerSection: some View {
        EstimateCustomerCard(
            client: currentClient,
            assignAction: { isShowingClientPicker = true },
            changeAction: currentClient != nil ? { isShowingClientPicker = true } : nil
        )
    }

    private var quickActionsSection: some View {
        EstimateQuickActionsCard(
            client: currentClient,
            callAction: callClient,
            textAction: textClient,
            followUpAction: followUpClient
        )
    }

    @ViewBuilder
    private var materialsSection: some View {
        VStack(spacing: 16) {
            RoundedCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Labor")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.7))

                            Text("\(estimate.laborLines.count) items")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Button(action: addLaborLine) {
                            Label("Add Labor Line", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.white.opacity(0.16))
                                .clipShape(Capsule())
                                .foregroundColor(.white)
                        }
                    }

                    if estimate.laborLines.isEmpty {
                        Text("No labor added yet.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        ForEach($estimate.laborLines) { $labor in
                            EditableLaborRow(
                                laborLine: $labor,
                                isLast: labor.id == estimate.laborLines.last?.id,
                                deleteAction: { deleteLaborLine(labor) }
                            )
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.15))

                    HStack {
                        Text("Labor Subtotal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(estimate.laborSubtotal, format: .currency(code: "USD"))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                }
            }

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
                            EditableMaterialRow(
                                material: $material,
                                showDivider: material.id != estimate.materials.last?.id,
                                deleteAction: { deleteMaterial(material) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var previewSheetBinding: Binding<Bool> {
        Binding(
            get: { estimateVM.isShowingPreview },
            set: { estimateVM.isShowingPreview = $0 }
        )
    }

    private var previewErrorBinding: Binding<Bool> {
        Binding(
            get: { estimateVM.previewError != nil },
            set: {
                if !$0 {
                    estimateVM.previewError = nil
                }
            }
        )
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func clientRow(for client: Client) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.name.isEmpty ? client.company : client.name)
                .font(.headline)
            if !client.company.isEmpty, !client.name.isEmpty {
                Text(client.company)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if !client.email.isEmpty {
                Text(client.email)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ToolbarContentBuilder
    private var clientPickerToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { isShowingClientPicker = false }
        }
    }

    private func client(for job: Job) -> Client? {
        guard let clientId = job.clientId else { return nil }
        return clientVM.clients.first(where: { $0.id == clientId })
    }

    private var filteredClients: [Client] {
        guard clientSearchText.isEmpty == false else { return clientVM.clients }

        return clientVM.clients.filter { client in
            let query = clientSearchText.lowercased()
            return client.name.lowercased().contains(query)
                || client.company.lowercased().contains(query)
                || client.email.lowercased().contains(query)
        }
    }

    // MARK: - Materials & labor editing

    private func addMaterial() {
        showingMaterialEditor = true
    }

    private func addLaborLine() {
        estimate.laborLines.append(LaborLine(id: UUID(), title: "Labor", hours: 1, rate: 0))
        vm.update(estimate)
    }

    private func deleteMaterial(_ material: Material) {
        if let index = estimate.materials.firstIndex(where: { $0.id == material.id }) {
            estimate.materials.remove(at: index)
            vm.update(estimate)
        }
    }

    private func deleteLaborLine(_ labor: LaborLine) {
        if let index = estimate.laborLines.firstIndex(where: { $0.id == labor.id }) {
            estimate.laborLines.remove(at: index)
            vm.update(estimate)
        }
    }

    private func assignClient(_ client: Client) {
        estimate.clientId = client.id
        vm.assignClient(jobID: estimate.id, to: client.id)
        isShowingClientPicker = false
    }

    private func previewEstimate() {
        estimateVM.preview(
            estimate: estimate,
            client: client(for: estimate),
            company: companySettings.settings
        )
    }

    private func shareEstimatePDF() {
        do {
            let pdfURL = try estimateVM.generatePDF(
                for: estimate,
                client: client(for: estimate),
                company: companySettings.settings
            )

            let pdfData = try Data(contentsOf: pdfURL)
            let shareURL = try PDFTempWriter.exportShareablePDF(
                data: pdfData,
                fileName: "Estimate-\(estimate.name)"
            )

            let fileExists = FileManager.default.fileExists(atPath: shareURL.path)
            #if DEBUG
            let size = (try? FileManager.default.attributesOfItem(atPath: shareURL.path)[.size] as? NSNumber)?.intValue ?? 0
            print("[SharePDF] URL: \(shareURL)")
            print("[SharePDF] fileExists: \(fileExists)")
            print("[SharePDF] fileSize: \(size)")
            #endif

            guard fileExists else {
                shareError = "PDF file missing"
                return
            }

            let shareItem = PDFActivityItemSource(
                url: shareURL,
                title: "Estimate \(estimate.name)"
            )

            DispatchQueue.main.async {
                shareItems = [emailMessageToShare(), shareItem]
                isShowingShareSheet = true
            }
        } catch {
            shareError = error.localizedDescription
        }
    }

    private func editEstimate() {
        showingMaterialManager = true
    }

    private func convertToInvoice() {
        let clientName = clientVM.clients.first(where: { $0.id == estimate.clientId })?.name ?? "Unassigned"

        let invoice = Invoice(
            id: UUID(),
            ownerID: Auth.auth().currentUser?.uid ?? "",
            invoiceNumber: InvoiceNumberManager.shared.generateInvoiceNumber(),
            title: estimate.name,
            clientID: estimate.clientId,
            clientName: clientName,
            materials: estimate.materials,
            laborLines: estimate.laborLines,
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

    private func emailMessageToShare() -> String {
        let normalized = emailTemplateSettings.defaultEmailMessage
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return "Attached is your document."
        }

        return normalized
    }

}

private struct EditableLaborRow: View {
    @Binding var laborLine: LaborLine
    let isLast: Bool
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: $laborLine.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("\(laborLine.hours, format: .number.precision(.fractionLength(2))) × \(laborLine.rate, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    HStack {
                        TextField("Hours", value: $laborLine.hours, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        TextField("Rate", value: $laborLine.rate, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Spacer()

                Text(laborLine.total, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteAction()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        if !isLast {
            Divider().overlay(Color.white.opacity(0.15))
        }
    }
}

private struct EditableMaterialRow: View {
    @Binding var material: Material
    let showDivider: Bool
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Description", text: $material.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("\(String(format: "%.2f", material.quantity)) × \(material.unitCost, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    if let url = material.productURL {
                        Link("See Product Information", destination: url)
                            .font(.caption2)
                            .foregroundColor(.blue.opacity(0.9))
                            .lineLimit(1)
                    }
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
                deleteAction()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        if showDivider {
            Divider().overlay(Color.white.opacity(0.15))
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
                            Button(action: editLaborAction) {
                                Label("Add Labor Line", systemImage: "wrench.and.screwdriver")
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
    let shareAction: () -> Void
    let editAction: () -> Void
    let convertAction: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

                if horizontalSizeClass == .compact {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        Button(action: previewAction) {
                            Label("Preview Estimate", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(PrimaryBlueButton())
                        .disabled(estimate == nil)

                        Button(action: shareAction) {
                            Label("Share / Email PDF", systemImage: "square.and.arrow.up")
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
                } else {
                    HStack(spacing: 12) {
                        Button(action: previewAction) {
                            Label("Preview Estimate", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(PrimaryBlueButton())
                        .disabled(estimate == nil)

                        Button(action: shareAction) {
                            Label("Share / Email PDF", systemImage: "square.and.arrow.up")
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
}

struct EstimateCustomerCard: View {
    let client: Client?
    let assignAction: () -> Void
    let changeAction: (() -> Void)?

    init(
        client: Client?,
        assignAction: @escaping () -> Void = {},
        changeAction: (() -> Void)? = nil
    ) {
        self.client = client
        self.assignAction = assignAction
        self.changeAction = changeAction
    }

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
                        if let client {
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(clientDisplayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text(client.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text(client.address.isEmpty ? "—" : client.address)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text(client.phone.isEmpty ? "—" : client.phone)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text(client.email.isEmpty ? "—" : client.email)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }

                            if let changeAction {
                                Button(action: changeAction) {
                                    Text("Change")
                                        .font(.caption.weight(.semibold))
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.white.opacity(0.16))
                                        .clipShape(Capsule())
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            Button(action: assignAction) {
                                Text("Assign Client")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.white.opacity(0.16))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white)
                            }
                        }
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
                                if let url = material.productURL {
                                    Link("See Product Information", destination: url)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                }
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
                                if let url = material.productURL {
                                    Link("See Product Information", destination: url)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .lineLimit(1)
                                }
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

