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

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: JobViewModel
    @EnvironmentObject private var clientVM: ClientViewModel

    let mode: Mode

    @State private var name: String
    @State private var category: String
    @State private var labourHours: String
    @State private var laborRate: String
    @State private var selectedClientId: UUID?
    @State private var isPresentingNewClientSheet = false

    // MARK: - Init

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add:
            _name = State(initialValue: "")
            _category = State(initialValue: "")
            _labourHours = State(initialValue: "")
            _laborRate = State(initialValue: "")
            _selectedClientId = State(initialValue: nil)
        case .edit(let job):
            _name = State(initialValue: job.name)
            _category = State(initialValue: job.category)
            _labourHours = State(initialValue: String(job.laborHours))
            _laborRate = State(initialValue: String(job.laborRate))
            _selectedClientId = State(initialValue: job.clientId)
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

                    Picker("Client", selection: $selectedClientId) {
                        Text("Unassigned").tag(UUID?.none)
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

                Section(header: Text("Labor (optional)")) {
                    TextField("Hours", text: $labourHours)
                        .keyboardType(.decimalPad)
                    TextField("Rate", text: $laborRate)
                        .keyboardType(.decimalPad)
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

        let hoursTrimmed = labourHours.trimmingCharacters(in: .whitespaces)
        let rateTrimmed  = laborRate.trimmingCharacters(in: .whitespaces)

        if !hoursTrimmed.isEmpty && Double(hoursTrimmed) == nil { return false }
        if !rateTrimmed.isEmpty && Double(rateTrimmed) == nil { return false }

        return true
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Empty fields default to 0
        let h = Double(labourHours.trimmingCharacters(in: .whitespaces)) ?? 0
        let r = Double(laborRate.trimmingCharacters(in: .whitespaces)) ?? 0

        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .add:
            let job = Job(
                name: trimmedName,
                category: trimmedCategory,
                laborHours: h,
                laborRate: r,
                materials: [],
                clientId: selectedClientId
            )
            vm.add(job)

        case .edit(let existing):
            var updated = existing
            updated.name = trimmedName
            updated.category = trimmedCategory
            updated.laborHours = h
            updated.laborRate = r
            updated.clientId = selectedClientId
            vm.update(updated)
        }

        dismiss()
    }
}

struct NewClientSheet: View {
    @EnvironmentObject private var clientVM: ClientViewModel
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
}
