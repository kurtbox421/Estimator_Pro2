import SwiftUI
import UIKit

struct InvoiceDetailView: View {
    @EnvironmentObject var jobVM: JobViewModel
    @EnvironmentObject var clientVM: ClientViewModel
    @EnvironmentObject private var companySettings: CompanySettingsStore

    @ObservedObject var invoiceVM: InvoiceViewModel
    let invoice: Invoice

    @State private var editingMaterial: Material?
    @State private var editingMaterialIndex: Int?
    @State private var showingMaterialSheet = false

    // MARK: - Derived data

    private var currentInvoice: Invoice {
        invoiceVM.invoices.first(where: { $0.id == invoice.id }) ?? invoice
    }

    private var client: Client? {
        guard let clientID = currentInvoice.clientID else { return nil }
        return clientVM.clients.first(where: { $0.id == clientID })
    }

    // MARK: - Body

    var body: some View {
        JobDocumentLayout(
            summary: InvoiceSummaryCard(invoice: currentInvoice, client: client),
            document: InvoiceDocumentCard(
                invoice: currentInvoice,
                previewAction: handlePreviewInvoice,
                statusAction: markInvoiceAsSent
            ),
            customer: { EstimateCustomerCard(client: client) },
            quickActions: {
                EstimateQuickActionsCard(
                    client: client,
                    callAction: callClient,
                    textAction: textClient,
                    followUpAction: followUpClient
                )
            },
            materials: {
                MaterialsSection(
                    materials: currentInvoice.materials,
                    addAction: addMaterial,
                    editAction: editMaterial,
                    deleteAction: deleteMaterial
                )
            }
        )
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMaterialSheet) {
            MaterialEditView(material: editingMaterial) { material in
                if let index = editingMaterialIndex {
                    invoiceVM.updateMaterial(in: currentInvoice, at: index, with: material)
                } else {
                    invoiceVM.addMaterial(to: currentInvoice, material: material)
                }

                clearMaterialEditingState()
            }
            .onDisappear(perform: clearMaterialEditingState)
        }
        .sheet(isPresented: Binding(get: { invoiceVM.isShowingPreview }, set: { invoiceVM.isShowingPreview = $0 })) {
            if let url = invoiceVM.previewURL {
                PDFPreviewSheet(url: url)
            } else {
                Text("No PDF available.")
            }
        }
        .alert(
            "Unable to generate PDF",
            isPresented: Binding(get: { invoiceVM.previewError != nil }, set: { if !$0 { invoiceVM.previewError = nil } })
        ) {
            Button("OK", role: .cancel) {
                invoiceVM.previewError = nil
            }
        } message: {
            Text(invoiceVM.previewError ?? "Unknown error")
        }
    }

    // MARK: - Actions

    private func addMaterial() {
        editingMaterial = Material(name: "", quantity: 1, unitCost: 0)
        editingMaterialIndex = nil
        showingMaterialSheet = true
    }

    private func editMaterial(_ index: Int) {
        guard currentInvoice.materials.indices.contains(index) else { return }
        editingMaterial = currentInvoice.materials[index]
        editingMaterialIndex = index
        showingMaterialSheet = true
    }

    private func deleteMaterial(_ index: Int) {
        invoiceVM.removeMaterial(from: currentInvoice, at: index)
    }

    private func clearMaterialEditingState() {
        editingMaterial = nil
        editingMaterialIndex = nil
    }

    private func handlePreviewInvoice() {
        invoiceVM.preview(invoice: currentInvoice, client: client, company: companySettings.settings)
    }

    private func markInvoiceAsSent() {
        var updatedInvoice = currentInvoice
        updatedInvoice.status = updatedInvoice.status == .sent ? .draft : .sent
        invoiceVM.update(updatedInvoice)
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
        guard let email = client?.email, !email.isEmpty, let url = URL(string: "mailto:\(email)") else { return }
        UIApplication.shared.open(url)
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
                    Button {
                        previewAction()
                    } label: {
                        Label("Preview Invoice", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: statusAction) {
                        Label(invoice.status == .sent ? "Mark as Draft" : "Mark as Sent", systemImage: invoice.status == .sent ? "arrow.uturn.backward" : "paperplane.fill")
                    }
                    .buttonStyle(PrimaryBlueButton())
                }
            }
        }
    }
}
