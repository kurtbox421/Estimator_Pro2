import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject var jobVM: JobViewModel
    @EnvironmentObject var invoiceVM: InvoiceViewModel
    @EnvironmentObject var clientVM: ClientViewModel

    let invoiceID: Invoice.ID

    @State private var invoice: Invoice
    @State private var isShowingEditSheet = false
    @State private var editingMaterialIndex: Int?
    @State private var showingMaterialSheet = false

    init(invoice: Invoice) {
        invoiceID = invoice.id
        _invoice = State(initialValue: invoice)
    }

    private var client: Client? {
        guard let clientID = invoice.clientID else { return nil }
        return clientVM.clients.first(where: { $0.id == clientID })
    }

    private var formattedAmount: String {
        invoice.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.15, blue: 0.12),
                    Color(red: 0.20, green: 0.35, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                        .padding(.horizontal, 24)

                    materialsCard
                        .padding(.horizontal, 24)

                    invoiceDetailsCard
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(invoice.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isShowingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            NavigationView {
                AddEditInvoiceView(mode: .edit(invoice))
            }
            .environmentObject(invoiceVM)
            .environmentObject(clientVM)
        }
        .sheet(isPresented: $showingMaterialSheet) {
            if let index = editingMaterialIndex {
                AddMaterialView(
                    mode: .editInInvoice(invoice: invoice, index: index),
                    jobVM: jobVM,
                    invoiceVM: invoiceVM
                )
            } else {
                AddMaterialView(
                    mode: .addToInvoice(invoice: invoice),
                    jobVM: jobVM,
                    invoiceVM: invoiceVM
                )
            }
        }
        .onAppear(perform: syncInvoiceWithViewModel)
        .onReceive(invoiceVM.$invoices) { _ in
            syncInvoiceWithViewModel()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(invoice.title)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(client?.name ?? invoice.clientName)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            Divider().background(Color.white.opacity(0.25))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(formattedAmount)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(invoice.status.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(invoice.status.pillColor)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }

                Spacer()

                if let dueDate = invoice.dueDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due date")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(dueDate, formatter: invoiceDueDateFormatter)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
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
    }

    private var materialsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Materials")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(invoice.materials.count) items")
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

            if invoice.materials.isEmpty {
                Text("No materials listed for this invoice.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            } else {
                ForEach(invoice.materials.indices, id: \.self) { index in
                    let material = invoice.materials[index]
                    MaterialRow(material: material)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") {
                                editingMaterialIndex = index
                                showingMaterialSheet = true
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                invoiceVM.removeMaterial(at: index, in: invoice)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var invoiceDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice details")
                .font(.headline)
                .foregroundColor(.white)

            clientDetailRow
            detailRow(title: "Status", value: invoice.status.displayName)
            detailRow(title: "Amount", value: formattedAmount)
            detailRow(
                title: "Due date",
                value: invoice.dueDate.map { invoiceDueDateFormatter.string(from: $0) } ?? "Not set"
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var clientDetailRow: some View {
        HStack(alignment: .top) {
            Text("Client")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(client?.name ?? invoice.clientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                if let client {
                    if !client.company.isEmpty {
                        Text(client.company)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    if !client.address.isEmpty {
                        Text(client.address)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    if !client.phone.isEmpty {
                        Text(client.phone)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    if !client.email.isEmpty {
                        Text(client.email)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }

    private func syncInvoiceWithViewModel() {
        guard let updatedInvoice = invoiceVM.invoices.first(where: { $0.id == invoiceID }) else { return }
        invoice = updatedInvoice
    }
}

private struct MaterialRow: View {
    let material: Material

    var body: some View {
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

            Text("$\(material.total, specifier: "%.2f")")
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
    }
}
