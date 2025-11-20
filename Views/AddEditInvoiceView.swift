import SwiftUI

struct AddEditInvoiceView: View {
    enum Mode {
        case add
        case edit(Invoice)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    @EnvironmentObject private var clientVM: ClientViewModel

    let mode: Mode

    @State private var title: String
    @State private var clientName: String
    @State private var amount: String
    @State private var status: Invoice.InvoiceStatus
    @State private var includeDueDate: Bool
    @State private var dueDate: Date
    @State private var isPresentingNewClientSheet = false

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add:
            _title = State(initialValue: "")
            _clientName = State(initialValue: "")
            _amount = State(initialValue: "")
            _status = State(initialValue: .draft)
            _includeDueDate = State(initialValue: false)
            _dueDate = State(initialValue: Date())
        case .edit(let invoice):
            _title = State(initialValue: invoice.title)
            _clientName = State(initialValue: invoice.clientName)
            _amount = State(initialValue: String(invoice.amount))
            _status = State(initialValue: invoice.status)
            _includeDueDate = State(initialValue: invoice.dueDate != nil)
            _dueDate = State(initialValue: invoice.dueDate ?? Date())
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.38, green: 0.15, blue: 0.14),
                    Color(red: 0.18, green: 0.32, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Form {
                Section(header: Text("Invoice details")) {
                    TextField("Title", text: $title)
                    Picker("Client", selection: clientSelectionBinding) {
                        Text(clientName.isEmpty ? "Unassigned" : clientName)
                            .tag(UUID?.none)

                        ForEach(clientVM.clients) { client in
                            Text(client.name.isEmpty ? "New client" : client.name)
                                .tag(Optional(client.id))
                        }

                        Divider()

                        Button {
                            isPresentingNewClientSheet = true
                        } label: {
                            Label("New client…", systemImage: "person.badge.plus")
                        }
                    }
                }

                Section(header: Text("Billing")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Status", selection: $status) {
                        ForEach(Invoice.InvoiceStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                Section(header: Text("Due date (optional)")) {
                    Toggle("Include due date", isOn: $includeDueDate.animation())
                    if includeDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text("Save Invoice")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!isValid)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(modeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!isValid)
            }
        }
        .sheet(isPresented: $isPresentingNewClientSheet) {
            NavigationView {
                NewClientSheet { newClient in
                    clientName = newClient.name
                }
                .environmentObject(clientVM)
            }
        }
    }

    private var clientSelectionBinding: Binding<UUID?> {
        Binding(
            get: {
                clientVM.clients.first(where: { $0.name == clientName })?.id
            },
            set: { newValue in
                if let id = newValue, let client = clientVM.clients.first(where: { $0.id == id }) {
                    clientName = client.name
                } else {
                    clientName = ""
                }
            }
        )
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "New Invoice"
        case .edit: return "Edit Invoice"
        }
    }

    private var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty || trimmedClient.isEmpty { return false }
        return Double(amount.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountValue = Double(amount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard !trimmedTitle.isEmpty, !trimmedClient.isEmpty, amountValue.isFinite else { return }

        let dueDateValue = includeDueDate ? dueDate : nil

        switch mode {
        case .add:
            let invoice = Invoice(
                title: trimmedTitle,
                clientName: trimmedClient,
                amount: amountValue,
                status: status,
                dueDate: dueDateValue
            )
            invoiceVM.add(invoice)

        case .edit(let existing):
            var updated = existing
            updated.title = trimmedTitle
            updated.clientName = trimmedClient
            updated.amount = amountValue
            updated.status = status
            updated.dueDate = dueDateValue
            invoiceVM.update(updated)
        }

        dismiss()
    }
}

private let addInvoiceModeID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

extension AddEditInvoiceView.Mode: Identifiable {
    var id: UUID {
        switch self {
        case .add:
            return addInvoiceModeID
        case .edit(let invoice):
            return invoice.id
        }
    }
}
