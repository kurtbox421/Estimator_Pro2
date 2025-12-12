import SwiftUI
import UIKit

struct InvoiceDetailView: View {
    // MARK: - Environment

    @EnvironmentObject var clientVM: ClientViewModel
    @EnvironmentObject var invoiceVM: InvoiceViewModel
    @EnvironmentObject var companySettings: CompanySettingsStore

    // MARK: - Binding

    @Binding var invoice: Invoice
    @State private var isPresentingInvoiceEditor = false
    @State private var isShowingClientPicker = false
    @State private var clientSearchText = ""
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareError: String?

    // MARK: - Derived data

    private var client: Client? {
        guard let clientID = invoice.clientID else { return nil }
        return clientVM.clients.first(where: { $0.id == clientID })
    }

    // MARK: - Body

    var body: some View {
        JobDocumentLayout(
            summary: VStack(spacing: 12) {
                InvoiceSummaryCard(invoice: invoice, client: client)
            },
            document: InvoiceDocumentCard(
                invoice: invoice,
                previewAction: handlePreviewInvoice,
                shareAction: shareInvoicePDF,
                editAction: { isPresentingInvoiceEditor = true },
                statusAction: markInvoiceAsSent
            ),
            customer: {
                EstimateCustomerCard(
                    client: client,
                    assignAction: { isShowingClientPicker = true },
                    changeAction: client != nil ? { isShowingClientPicker = true } : nil
                )
            },
            quickActions: {
                EstimateQuickActionsCard(
                    client: client,
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

                                Text("\(invoice.materials.count) items")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()
                        }

                        if invoice.materials.isEmpty {
                            Text("No materials added yet.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            ForEach($invoice.materials) { $material in
                                InvoiceMaterialRow(
                                    material: $material,
                                    isLast: material.id == invoice.materials.last?.id,
                                    deleteAction: { deleteMaterial(material) }
                                )
                            }
                        }
                    }
                }
            }
        )
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingInvoiceEditor) {
            NavigationView {
                AddEditInvoiceView(mode: .edit(invoice))
                    .environmentObject(invoiceVM)
                    .environmentObject(clientVM)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { invoiceVM.isShowingPreview },
                set: { invoiceVM.isShowingPreview = $0 }
            )
        ) {
            if let url = invoiceVM.previewURL {
                PDFPreviewSheet(url: url)
            } else {
                Text("No PDF available.")
            }
        }
        .alert(
            "Unable to generate PDF",
            isPresented: Binding(
                get: { invoiceVM.previewError != nil },
                set: { if !$0 { invoiceVM.previewError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                invoiceVM.previewError = nil
            }
        } message: {
            Text(invoiceVM.previewError ?? "Unknown error")
        }
        .alert(
            "Unable to share PDF",
            isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                shareError = nil
            }
        } message: {
            Text(shareError ?? "Unknown error")
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $isShowingClientPicker) {
            NavigationView {
                List {
                    ForEach(filteredClients) { client in
                        Button {
                            assignClient(client)
                        } label: {
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
                    }
                }
                .searchable(text: $clientSearchText)
                .navigationTitle("Assign Client")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingClientPicker = false }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteMaterial(_ material: Material) {
        if let index = invoice.materials.firstIndex(where: { $0.id == material.id }) {
            invoice.materials.remove(at: index)
            invoiceVM.update(invoice)
        }
    }

    private func handlePreviewInvoice() {
        invoiceVM.preview(invoice: invoice, client: client, company: companySettings.settings)
    }

    private func shareInvoicePDF() {
        do {
            let pdfURL = try invoiceVM.generateInvoicePDF(
                for: invoice,
                client: client,
                company: companySettings.settings
            )

            let pdfData = try Data(contentsOf: pdfURL)
            let shareURL = try PDFTempWriter.exportShareablePDF(
                data: pdfData,
                fileName: "Invoice-\(invoice.invoiceNumber)"
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
                title: "Invoice \(invoice.invoiceNumber)"
            )

            DispatchQueue.main.async {
                shareItems = [shareItem]
                isShowingShareSheet = true
            }
        } catch {
            shareError = error.localizedDescription
        }
    }

    private func markInvoiceAsSent() {
        invoice.status = invoice.status == .sent ? .draft : .sent
        invoiceVM.update(invoice)
    }

    private func callClient() {
        guard let phone = client?.phone, !phone.isEmpty else { return }
        let digits = phone.filter("0123456789".contains)
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func textClient() {
        guard let phone = client?.phone, !phone.isEmpty else { return }
        let digits = phone.filter("0123456789".contains)
        guard let url = URL(string: "sms:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func followUpClient() {
        guard
            let email = client?.email,
            !email.isEmpty,
            let url = URL(string: "mailto:\(email)")
        else { return }

        UIApplication.shared.open(url)
    }

    private func assignClient(_ client: Client) {
        invoice.clientID = client.id
        invoice.clientName = resolvedClientName(from: client)
        invoiceVM.update(invoice)
        isShowingClientPicker = false
    }

    private var filteredClients: [Client] {
        guard clientSearchText.isEmpty == false else { return clientVM.clients }

        let query = clientSearchText.lowercased()
        return clientVM.clients.filter { client in
            client.name.lowercased().contains(query)
                || client.company.lowercased().contains(query)
                || client.email.lowercased().contains(query)
        }
    }

    private func resolvedClientName(from client: Client) -> String {
        if client.name.isEmpty == false { return client.name }
        if client.company.isEmpty == false { return client.company }
        return "Not Assigned"
    }
}

// MARK: - Cards

private struct InvoiceSummaryCard: View {
    let invoice: Invoice
    let client: Client?

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
                        Text(invoice.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        let clientName = client?.name ?? invoice.clientName
                        if !clientName.isEmpty {
                            Text(clientName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Text("Invoice #: \(invoice.invoiceNumber)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.85))

                        HStack(spacing: 8) {
                            Label("Invoice", systemImage: "doc.text")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                )
                                .foregroundColor(.white)

                            Text(invoice.status.displayName)
                                .font(.caption.weight(.semibold))
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
                        Text("\(invoice.materials.count)")
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
                    Text(invoice.amount.formatted(.currency(code: "USD")))
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

private struct InvoiceDocumentCard: View {
    let invoice: Invoice
    let previewAction: () -> Void
    let shareAction: () -> Void
    let editAction: () -> Void
    let statusAction: () -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Document")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                Text("Invoice")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                Text("This job is currently an invoice. Use the actions below to manage or share it with your client.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 12) {
                    Button(action: previewAction) {
                        Label("Preview Invoice", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(PrimaryBlueButton())

                    Button(action: shareAction) {
                        Label("Share / Email PDF", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryBlueButton())

                    Button(action: editAction) {
                        Label("Edit Invoice", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(PrimaryBlueButton())

                    Button(action: statusAction) {
                        Label(
                            invoice.status == .sent ? "Mark as Draft" : "Mark as Sent",
                            systemImage: invoice.status == .sent ? "arrow.uturn.backward" : "paperplane.fill"
                        )
                    }
                    .buttonStyle(PrimaryBlueButton())
                }
            }
        }
    }
}

private struct InvoiceMaterialRow: View {
    @Binding var material: Material
    let isLast: Bool
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
            Button(role: .destructive, action: deleteAction) {
                Label("Delete", systemImage: "trash")
            }
        }

        if !isLast {
            Divider().overlay(Color.white.opacity(0.15))
        }
    }
}
