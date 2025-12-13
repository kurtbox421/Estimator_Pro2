//
//  AddEditJobView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//
import SwiftUI
import FirebaseAuth

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
    @State private var laborLines: [LaborLine]
    @State private var selectedClientId: UUID?

    // MARK: - Init

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add:
            _name = State(initialValue: "")
            _category = State(initialValue: "")
            _laborLines = State(initialValue: [])
            _selectedClientId = State(initialValue: nil)
        case .edit(let job):
            _name = State(initialValue: job.name)
            _category = State(initialValue: job.category)
            _laborLines = State(initialValue: job.laborLines)
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
                            HStack {
                                TextField("Hours", value: $labor.hours, format: .number)
                                    .keyboardType(.decimalPad)
                                TextField("Rate", value: $labor.rate, format: .number)
                                    .keyboardType(.decimalPad)
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
                        Text("Save Job")
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

        return true
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let ownerID = Auth.auth().currentUser?.uid ?? ""

        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let normalizedLaborLines = laborLines.map { line -> LaborLine in
            let trimmedTitle = line.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return LaborLine(
                id: line.id,
                title: trimmedTitle.isEmpty ? "Labor" : trimmedTitle,
                hours: debugCheckNaN(line.hours, label: "job labor hours"),
                rate: debugCheckNaN(line.rate, label: "job labor rate")
            )
        }

        switch mode {
        case .add:
            let job = Job(
                ownerID: ownerID,
                name: trimmedName,
                category: trimmedCategory,
                laborLines: normalizedLaborLines,
                materials: [],
                clientId: selectedClientId
            )
            vm.add(job)

        case .edit(let existing):
            var updated = existing
            updated.name = trimmedName
            updated.category = trimmedCategory
            updated.laborLines = normalizedLaborLines
            updated.clientId = selectedClientId
            if updated.ownerID.isEmpty {
                updated.ownerID = ownerID
            }
            vm.update(updated)
        }

        dismiss()
    }
}
