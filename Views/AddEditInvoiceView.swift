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
    @State private var selectedClientId: UUID?
    @State private var clientName: String
    @State private var status: Invoice.InvoiceStatus
    @State private var includeDueDate: Bool
    @State private var dueDate: Date
    @State private var isPresentingNewClientSheet = false

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add:
            _title = State(initialValue: "")
            _selectedClientId = State(initialValue: nil)
            _clientName = State(initialValue: "")
            _status = State(initialValue: .draft)
            _includeDueDate = State(initialValue: false)
            _dueDate = State(initialValue: Date())
        case .edit(let invoice):
            _title = State(initialValue: invoice.title)
            _selectedClientId = State(initialValue: invoice.clientID)
            _clientName = State(initialValue: invoice.clientName)
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
                    Picker("Client", selection: $selectedClientId) {
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
        .onChange(of: selectedClientId) { newValue in
            guard let id = newValue, let client = clientVM.clients.first(where: { $0.id == id }) else {
                clientName = ""
                return
            }
            clientName = client.name
        }
        .sheet(isPresented: $isPresentingNewClientSheet) {
            NavigationView {
                NewClientSheet { newClient in
                    clientName = newClient.name
                    selectedClientId = newClient.id
                }
                .environmentObject(clientVM)
            }
        }
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
        return !trimmedTitle.isEmpty && !trimmedClient.isEmpty
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedClient.isEmpty else { return }

        let dueDateValue = includeDueDate ? dueDate : nil

        switch mode {
        case .add:
            let invoice = Invoice(
                title: trimmedTitle,
                clientID: selectedClientId,
                clientName: trimmedClient,
                materials: [],
                status: status,
                dueDate: dueDateValue
            )
            invoiceVM.add(invoice)

        case .edit(let existing):
            var updated = existing
            updated.title = trimmedTitle
            updated.clientID = selectedClientId
            updated.clientName = trimmedClient
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
