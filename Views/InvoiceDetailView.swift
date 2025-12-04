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
                editAction: { isPresentingInvoiceEditor = true },
                statusAction: markInvoiceAsSent
            ),
            customer: {
                EstimateCustomerCard(client: client)
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
