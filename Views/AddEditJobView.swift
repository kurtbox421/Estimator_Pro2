//
//  AddEditJobView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//
import SwiftUI

struct AddEditJobView: View {
    enum Mode {
        case add
        case edit(Job)
    }

    enum ClientSelection: Hashable {
        case unassigned
        case existing(UUID)
        case newClient
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: JobViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var session: SessionManager

    let mode: Mode

    @State private var name: String
    @State private var category: String
    @State private var laborLines: [LaborLine]
    @State private var selectedClientId: UUID?
    @State private var isPresentingNewClientSheet = false
    @State private var clientSelection: ClientSelection
    @State private var lastNonNewClientSelection: ClientSelection

    struct MaterialDraft: Identifiable {
        let id = UUID()
        var name: String = ""
        var quantity: String = ""
        var unitCost: String = ""
        var productURL: String = ""
    }

    @State private var materialDrafts: [MaterialDraft]

    // MARK: - Init

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add:
            _name = State(initialValue: "")
            _category = State(initialValue: "")
            _laborLines = State(initialValue: [])
            _selectedClientId = State(initialValue: nil)
            _materialDrafts = State(initialValue: [MaterialDraft()])
            let initialSelection: ClientSelection = .unassigned
            _clientSelection = State(initialValue: initialSelection)
            _lastNonNewClientSelection = State(initialValue: initialSelection)
        case .edit(let job):
            _name = State(initialValue: job.name)
            _category = State(initialValue: job.category)
            _laborLines = State(initialValue: job.laborLines)
            _selectedClientId = State(initialValue: job.clientId)
            _materialDrafts = State(initialValue: job.materials.map { material in
                MaterialDraft(
                    name: material.name,
                    quantity: String(material.quantity),
                    unitCost: String(material.unitCost),
                    productURL: material.productURL?.absoluteString ?? ""
                )
            })
            let initialSelection: ClientSelection = job.clientId.map { .existing($0) } ?? .unassigned
            _clientSelection = State(initialValue: initialSelection)
            _lastNonNewClientSelection = State(initialValue: initialSelection)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.18, blue: 0.32),
                    Color(red: 0.05, green: 0.30, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Form {
                Section(header: Text("Job info")) {
                    TextField("Job Name", text: $name)
                    TextField("Category (optional)", text: $category)

                    Picker("Client", selection: $clientSelection) {
                        Text("Unassigned").tag(ClientSelection.unassigned)

                        ForEach(clientVM.clients) { client in
                            Text(client.name.isEmpty ? "New client" : client.name)
                                .tag(ClientSelection.existing(client.id))
                        }

                        Divider()

                        Label("New client…", systemImage: "person.badge.plus")
                            .tag(ClientSelection.newClient)
                    }
                    .onChange(of: clientSelection) { _, newSelection in
                        switch newSelection {
                        case .unassigned:
                            selectedClientId = nil
                            lastNonNewClientSelection = newSelection

                        case .existing(let id):
                            selectedClientId = id
                            lastNonNewClientSelection = newSelection

                        case .newClient:
                            guard subscriptionManager.isPro else {
                                presentPaywallAfterDismissing()
                                return
                            }
                            isPresentingNewClientSheet = true
                            DispatchQueue.main.async {
                                clientSelection = lastNonNewClientSelection
                            }
                        }
                    }
                }

                Section(header: Text("Labor (optional)")) {
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

                Section(header: Text("Materials")) {
                    ForEach($materialDrafts) { $draft in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Description", text: $draft.name)
                                .onChange(of: draft.name) { _, _ in
                                    applyCommonMaterialPriceIfNeeded(for: draft.id)
                                }

                            HStack {
                                TextField("Qty", text: $draft.quantity)
                                    .keyboardType(.decimalPad)
                                    .onChange(of: draft.quantity) { _, _ in
                                        applyCommonMaterialPriceIfNeeded(for: draft.id)
                                    }

                                TextField("Unit Cost", text: $draft.unitCost)
                                    .keyboardType(.decimalPad)
                            }

                            TextField("Product URL (optional)", text: $draft.productURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteDraft(draft)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        materialDrafts.append(MaterialDraft())
                    } label: {
                        Label("Add Material", systemImage: "plus")
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text("Save Job")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!isValid)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $isPresentingNewClientSheet) {
            NavigationView {
                NewClientSheet { newClient in
                    selectedClientId = newClient.id
                    clientSelection = .existing(newClient.id)
                    lastNonNewClientSelection = .existing(newClient.id)
                }
                .environmentObject(clientVM)
            }
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
    }

    // MARK: - Helpers

    private var modeTitle: String {
        switch mode {
        case .add: return "New Job"
        case .edit: return "Edit Job"
        }
    }

    // Only require a name; numbers are optional but must be valid if present
    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty { return false }

        return materialDrafts.allSatisfy { isValidProductURL($0.productURL) }
    }

    private func deleteDraft(_ draft: MaterialDraft) {
        if let index = materialDrafts.firstIndex(where: { $0.id == draft.id }) {
            materialDrafts.remove(at: index)
        }
    }

    private func materialsFromDrafts() -> [Material] {
        materialDrafts.compactMap { draft in
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }

            let qty = debugCheckNaN(parseDouble(draft.quantity) ?? 0, label: "draft material quantity")
            let cost = debugCheckNaN(parseDouble(draft.unitCost) ?? 0, label: "draft material unit cost")
            let productURL = parsedURL(from: draft.productURL)

            return Material(
                id: UUID(),
                ownerID: session.uid ?? "",
                name: trimmedName,
                quantity: qty,
                unitCost: cost,
                productURL: productURL
            )
        }
    }

    private func isValidProductURL(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return parsedURL(from: text) != nil
    }

    private func parsedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        return url
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let normalizedLaborLines = laborLines.map { line -> LaborLine in
            let trimmedTitle = line.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return LaborLine(
                id: line.id,
                title: trimmedTitle.isEmpty ? "Labor" : trimmedTitle,
                hours: debugCheckNaN(line.hours, label: "job labor hours"),
                rate: debugCheckNaN(line.rate, label: "job labor rate")
            )
        }

        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let materials = materialsFromDrafts()

        switch mode {
        case .add:
            print("[Paywall] Running free limit check for estimates. Current count: \(vm.jobs.count)")
            if !subscriptionManager.isPro && vm.jobs.count >= 2 {
                print("[Paywall] Estimate limit exceeded for free tier.")
                Task { @MainActor in
                    print("[Paywall] Triggering paywall for estimate save.")
                    presentPaywallAfterDismissing()
                }
                return
            }
            let job = Job(
                name: trimmedName,
                category: trimmedCategory,
                laborLines: normalizedLaborLines,
                materials: materials,
                clientId: selectedClientId
            )
            vm.add(job)

        case .edit(let existing):
            var updated = existing
            updated.name = trimmedName
            updated.category = trimmedCategory
            updated.laborLines = normalizedLaborLines
            updated.clientId = selectedClientId
            updated.materials = materials
            vm.update(updated)
        }

        dismiss()
    }

    private func applyCommonMaterialPriceIfNeeded(for draftID: UUID) {
        guard let index = materialDrafts.firstIndex(where: { $0.id == draftID }) else { return }

        let name = materialDrafts[index].name
        guard let price = settingsManager.commonMaterialPrice(for: name),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if materialDrafts[index].unitCost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            materialDrafts[index].unitCost = String(format: "%.2f", price)
        }
    }

    private func presentPaywallAfterDismissing() {
        subscriptionManager.presentPaywallFromRoot(afterDismissing: dismiss)
    }
}

struct NewClientSheet: View {
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var company: String = ""
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var notes: String = ""

    let onSave: (Client) -> Void

    var body: some View {
        Form {
            Section("Basic info") {
                TextField("Client name", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("Company", text: $company)
                    .textInputAutocapitalization(.words)
            }

            Section("Contact") {
                TextField("Address", text: $address)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("New Client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscriptionManager.isPro else {
                            showPaywallAfterDismissingSheet()
                            return
                        }
                        let newClient = clientVM.addClient(
                            name: name.trimmingCharacters(in: .whitespaces),
                            company: company,
                            address: address,
                            phone: phone,
                        email: email,
                        notes: notes
                    )
                    onSave(newClient)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func showPaywallAfterDismissingSheet() {
        subscriptionManager.presentPaywallFromRoot(afterDismissing: dismiss)
    }
}
