import SwiftUI

struct SupplyDetailView: View {
    @EnvironmentObject private var inventoryVM: InventoryViewModel
    @State private var supply: SupplyItem

    @State private var showingRestock = false
    @State private var showingUse = false
    @State private var showingEdit = false
    @State private var changeAmount: Double = 0
    @State private var note: String = ""
    @State private var alertMessage: String?

    init(supply: SupplyItem) {
        _supply = State(initialValue: supply)
    }

    var body: some View {
        List {
            Section(header: Text("On-hand")) {
                HStack {
                    Text("Quantity")
                    Spacer()
                    Text("\(supply.onHand, specifier: "%.2f") \(supply.unit)")
                        .font(.title2.bold())
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Actions")) {
                Button {
                    changeAmount = 0
                    showingRestock = true
                } label: {
                    Label("Restock", systemImage: "arrow.down.circle")
                        .font(.headline)
                }

                Button {
                    changeAmount = 0
                    showingUse = true
                } label: {
                    Label("Use", systemImage: "arrow.up.circle")
                        .font(.headline)
                }
                .foregroundColor(.red)
            }

            if let transactions = inventoryVM.transactionsBySupply[supply.id ?? UUID()] {
                Section(header: Text("Transaction History")) {
                    ForEach(transactions, id: \.self) { transaction in
                        TransactionRow(transaction: transaction, unit: supply.unit)
                    }

                    if transactions.isEmpty {
                        Text("No history yet.")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(supply.displayName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .onAppear {
            if let id = supply.id {
                inventoryVM.fetchTransactions(for: id)
            }
        }
        .onReceive(inventoryVM.$supplies) { updated in
            if let id = supply.id, let newSupply = updated.first(where: { $0.id == id }) {
                supply = newSupply
            }
        }
        .sheet(isPresented: $showingRestock) {
            NavigationView {
                InventoryChangeSheet(
                    title: "Restock",
                    buttonColor: .green,
                    unit: supply.unit,
                    amount: $changeAmount,
                    note: $note,
                    onSubmit: { amount, note in
                        Task {
                            do {
                                try await inventoryVM.performRestock(for: supply, amount: amount, note: note)
                                if let id = supply.id {
                                    inventoryVM.fetchTransactions(for: id)
                                }
                                dismissSheet()
                            } catch {
                                alertMessage = error.localizedDescription
                            }
                        }
                    },
                    onCancel: dismissSheet
                )
            }
        }
        .sheet(isPresented: $showingUse) {
            NavigationView {
                InventoryChangeSheet(
                    title: "Use",
                    buttonColor: .red,
                    unit: supply.unit,
                    amount: $changeAmount,
                    note: $note,
                    onSubmit: { amount, note in
                        Task {
                            do {
                                try await inventoryVM.performUse(for: supply, amount: amount, note: note)
                                if let id = supply.id {
                                    inventoryVM.fetchTransactions(for: id)
                                }
                                dismissSheet()
                            } catch {
                                alertMessage = error.localizedDescription
                            }
                        }
                    },
                    onCancel: dismissSheet
                )
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationView {
                AddEditSupplyView(supply: supply) { updated in
                    supply = updated
                    inventoryVM.upsertSupply(updated)
                }
            }
        }
        .alert(item: $alertMessage) { message in
            Alert(title: Text("Error"), message: Text(message), dismissButton: .default(Text("OK")))
        }
    }

    private func dismissSheet() {
        changeAmount = 0
        note = ""
        showingRestock = false
        showingUse = false
    }
}

private struct InventoryChangeSheet: View {
    let title: String
    let buttonColor: Color
    let unit: String
    @Binding var amount: Double
    @Binding var note: String
    let onSubmit: (Double, String?) -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            Section(header: Text(title)) {
                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Unit")
                    Spacer()
                    Text(unit)
                        .foregroundColor(.secondary)
                }

                TextField("Note (optional)", text: $note)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(title) {
                    onSubmit(amount, note.isEmpty ? nil : note)
                }
                .disabled(amount <= 0)
                .foregroundColor(buttonColor)
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: InventoryTransaction
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transaction.type.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text("\(transaction.qtyChange, specifier: "%.2f") \(unit)")
                    .foregroundColor(transaction.qtyChange >= 0 ? .green : .red)
            }

            Text(transaction.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)

            if let note = transaction.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension String: Identifiable {
    public var id: String { self }
}
