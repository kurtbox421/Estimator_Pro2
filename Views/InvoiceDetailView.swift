import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject var jobVM: JobViewModel
    @EnvironmentObject var clientVM: ClientViewModel

    @ObservedObject var invoiceVM: InvoiceViewModel
    let invoice: Invoice

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

    private var formattedAmount: String {
        currentInvoice.amount.currencyFormatted
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            List {
                // HEADER (now includes invoice details)
                Section {
                    headerCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // MATERIALS
                Section(header: materialsHeader) {
                    materialsList
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(currentInvoice.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMaterialSheet) {
            if let index = editingMaterialIndex {
                AddMaterialView(
                    mode: .editInInvoice(invoice: currentInvoice, index: index),
                    jobVM: jobVM,
                    invoiceVM: invoiceVM
                )
            } else {
                AddMaterialView(
                    mode: .addToInvoice(invoice: currentInvoice),
                    jobVM: jobVM,
                    invoiceVM: invoiceVM
                )
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.40, green: 0.15, blue: 0.12),
                Color(red: 0.20, green: 0.35, blue: 0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header card (combined)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title & short client line
            Text(currentInvoice.title)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(client?.name ?? currentInvoice.clientName)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            Divider().background(Color.white.opacity(0.25))

            // Combined invoice details
            HStack(alignment: .top, spacing: 16) {
                // Left: full client details
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(client?.name ?? currentInvoice.clientName)
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

                Spacer()

                // Right: status, amount, due date
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(currentInvoice.status.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(currentInvoice.status.pillColor)
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(formattedAmount)
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Due date")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(
                            currentInvoice.dueDate.map { Formatters.invoiceDueDate.string(from: $0) }
                            ?? "Not set"
                        )
                        .font(.subheadline)
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

    // MARK: - Materials

    private var materialsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Materials")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(currentInvoice.materials.count) items")
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
            if currentInvoice.materials.isEmpty {
                Text("No materials listed for this invoice.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(currentInvoice.materials.indices, id: \.self) { index in
                    materialRow(for: index)
                        .listRowBackground(Color.clear)
                }
            }
        }
    }

    private func materialRow(for index: Int) -> some View {
        let material = currentInvoice.materials[index]

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

            Text(material.total.formatted(.currency(code: "USD")))
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
        .onTapGesture {
            editingMaterialIndex = index
            showingMaterialSheet = true
        }
        .contextMenu {
            Button {
                editingMaterialIndex = index
                showingMaterialSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                invoiceVM.removeMaterial(from: currentInvoice, at: index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Edit") {
                editingMaterialIndex = index
                showingMaterialSheet = true
            }
            .tint(.blue)

            Button(role: .destructive) {
                invoiceVM.removeMaterial(from: currentInvoice, at: index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
