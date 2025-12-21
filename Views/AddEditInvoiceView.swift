import SwiftUI

struct AddEditInvoiceView: View {
    enum Mode {
        case add
        case edit(Invoice)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var session: SessionManager

    let mode: Mode

    @State private var title: String
    @State private var selectedClientId: UUID?
    @State private var clientName: String
    @State private var status: Invoice.InvoiceStatus
    @State private var includeDueDate: Bool
    @State private var dueDate: Date
    @State private var materials: [Material]
    @State private var laborLines: [LaborLine]

    @State private var isPresentingMaterialSheet = false
    @State private var editingMaterialIndex: Int?
    @State private var materialName = ""
    @State private var materialQuantity = "1"
    @State private var materialUnitCost = ""
    @State private var materialProductURL = ""
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
            _materials = State(initialValue: [])
            _laborLines = State(initialValue: [])
        case .edit(let invoice):
            _title = State(initialValue: invoice.title)
            _selectedClientId = State(initialValue: invoice.clientID)
            _clientName = State(initialValue: invoice.clientName)
            _status = State(initialValue: invoice.status)
            _includeDueDate = State(initialValue: invoice.dueDate != nil)
            _dueDate = State(initialValue: invoice.dueDate ?? Date())
            _materials = State(initialValue: invoice.materials)
            _laborLines = State(initialValue: invoice.laborLines)
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
                            guard subscriptionManager.isPro else {
                                presentPaywallAfterDismissing()
                                return
                            }
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

                Section(header: Text("Materials")) {
                    if materials.isEmpty {
                        Text("No materials added yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(materials.enumerated()), id: \.element.id) { index, material in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(material.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(String(format: "%.2f", material.quantity)) × \(material.unitCost, format: .currency(code: "USD"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let url = material.productURL {
                                        Link("See Product Information", destination: url)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(material.total, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { startEditingMaterial(material, at: index) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteMaterial(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    startEditingMaterial(material, at: index)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }

                    Button(action: startAddingMaterial) {
                        Label("Add Material", systemImage: "plus")
                    }
                }

                Section(header: Text("Labor")) {
                    if laborLines.isEmpty {
                        Text("No labor lines added yet.")
                            .foregroundColor(.secondary)
                    }

                    ForEach($laborLines) { $labor in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Title", text: $labor.title)
                                .textFieldStyle(.plain)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            HStack {
                                TextField("Hours", value: $labor.hours, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                TextField("Rate", value: $labor.rate, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            HStack {
                                Spacer()
                                Text(labor.total, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                laborLines.removeAll { $0.id == labor.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        laborLines.append(LaborLine(id: UUID(), title: "Labor", hours: 0, rate: 0))
                    } label: {
                        Label("Add Labor Line", systemImage: "plus")
                    }

                    if !laborLines.isEmpty {
                        HStack {
                            Text("Labor Subtotal")
                            Spacer()
                            let subtotal = laborLines.reduce(0) { $0 + $1.total }
                            Text(subtotal, format: .currency(code: "USD"))
                                .font(.headline)
                        }
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
        .onChange(of: selectedClientId) { _, newValue in
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
        .sheet(isPresented: $isPresentingMaterialSheet) {
            NavigationView {
                Form {
                    Section("Material") {
                        TextField("Name", text: $materialName)
                    }

                    Section("Details") {
                        TextField("Quantity", text: $materialQuantity)
                            .keyboardType(.decimalPad)
                        TextField("Unit cost", text: $materialUnitCost)
                            .keyboardType(.decimalPad)
                        TextField("Product URL (optional)", text: $materialProductURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle(editingMaterialIndex == nil ? "Add Material" : "Edit Material")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresentingMaterialSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveMaterial() }
                            .disabled(!canSaveMaterial)
                    }
                }
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
        let normalizedLaborLines = laborLines.map { line -> LaborLine in
            let trimmedTitle = line.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return LaborLine(
                id: line.id,
                title: trimmedTitle.isEmpty ? "Labor" : trimmedTitle,
                hours: debugCheckNaN(line.hours, label: "invoice labor hours"),
                rate: debugCheckNaN(line.rate, label: "invoice labor rate")
            )
        }

        switch mode {
        case .add:
            print("[Paywall] Running free limit check for invoices. Current count: \(invoiceVM.invoices.count)")
            if !subscriptionManager.isPro && invoiceVM.invoices.count >= 2 {
                print("[Paywall] Invoice limit exceeded for free tier.")
                Task { @MainActor in
                    print("[Paywall] Triggering paywall for invoice save.")
                    presentPaywallAfterDismissing()
                }
                return
            }
            let invoice = Invoice(
                ownerID: session.uid ?? "",
                invoiceNumber: InvoiceNumberManager.generateInvoiceNumber(uid: session.uid),
                title: trimmedTitle,
                clientID: selectedClientId,
                clientName: trimmedClient,
                materials: materials,
                laborLines: normalizedLaborLines,
                status: status,
                dueDate: dueDateValue
            )
            invoiceVM.add(invoice)

        case .edit(let existing):
            var updated = existing
            updated.ownerID = existing.ownerID.isEmpty ? (session.uid ?? "") : existing.ownerID
            updated.title = trimmedTitle
            updated.clientID = selectedClientId
            updated.clientName = trimmedClient
            updated.materials = materials
            updated.laborLines = normalizedLaborLines
            updated.status = status
            updated.dueDate = dueDateValue
            invoiceVM.update(updated)
        }

        dismiss()
    }

    private func startAddingMaterial() {
        editingMaterialIndex = nil
        materialName = ""
        materialQuantity = "1"
        materialUnitCost = ""
        materialProductURL = ""
        isPresentingMaterialSheet = true
    }

    private func startEditingMaterial(_ material: Material, at index: Int) {
        editingMaterialIndex = index
        materialName = material.name
        materialQuantity = String(material.quantity)
        materialUnitCost = String(material.unitCost)
        materialProductURL = material.productURL?.absoluteString ?? ""
        isPresentingMaterialSheet = true
    }

    private var canSaveMaterial: Bool {
        !materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parseDouble(materialQuantity) != nil &&
        parseDouble(materialUnitCost) != nil &&
        isValidProductURL(materialProductURL)
    }

    private func saveMaterial() {
        guard let quantityValue = parseDouble(materialQuantity),
              let unitCostValue = parseDouble(materialUnitCost)
        else { return }

        let quantity = debugCheckNaN(quantityValue, label: "invoice material quantity")
        let unitCost = debugCheckNaN(unitCostValue, label: "invoice material unit cost")

        let trimmedName = materialName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let productURL = parsedProductURL(from: materialProductURL)

        let material = Material(
            id: editingMaterialIndex.flatMap { materials[$0].id } ?? UUID(),
            ownerID: session.uid ?? "",
            name: trimmedName,
            quantity: quantity,
            unitCost: unitCost,
            productURL: productURL
        )

        if let index = editingMaterialIndex, materials.indices.contains(index) {
            materials[index] = material
        } else {
            materials.append(material)
        }

        isPresentingMaterialSheet = false
    }

    private func deleteMaterial(at index: Int) {
        guard materials.indices.contains(index) else { return }
        materials.remove(at: index)
    }

    private func isValidProductURL(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return parsedProductURL(from: text) != nil
    }

    private func parsedProductURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        return url
    }

    private func presentPaywallAfterDismissing() {
        subscriptionManager.presentPaywallFromRoot(afterDismissing: dismiss)
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
