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

    let mode: Mode

    @State private var name: String
    @State private var category: String
    @State private var labourHours: String
    @State private var laborRate: String

    // MARK: - Init

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .add:
            _name = State(initialValue: "")
            _category = State(initialValue: "")
            _labourHours = State(initialValue: "")
            _laborRate = State(initialValue: "")
        case .edit(let job):
            _name = State(initialValue: job.name)
            _category = State(initialValue: job.category)
            _labourHours = State(initialValue: String(job.laborHours))
            _laborRate = State(initialValue: String(job.laborRate))
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
                laborRate: r
            )
            vm.add(job)

        case .edit(let existing):
            var updated = existing
            updated.name = trimmedName
            updated.category = trimmedCategory
            updated.laborHours = h
            updated.laborRate = r
            vm.update(updated)
        }

        dismiss()
    }
}
