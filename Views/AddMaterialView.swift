//
//  AddMaterialView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

struct AddMaterialView: View {
    enum Mode {
        case add
        case edit(Material)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let mode: Mode
    var onSave: (Material) -> Void

    @State private var name: String
    @State private var quantity: String
    @State private var unitCost: String

    init(mode: Mode = .add, onSave: @escaping (Material) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .add:
            _name = State(initialValue: "")
            _quantity = State(initialValue: "")
            _unitCost = State(initialValue: "")
        case .edit(let material):
            _name = State(initialValue: material.name)
            _quantity = State(initialValue: String(material.quantity))
            _unitCost = State(initialValue: String(material.unitCost))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Material")) {
                    TextField("Name", text: $name)
                }

                Section(header: Text("Details")) {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Unit cost", text: $unitCost)
                        .keyboardType(.decimalPad)
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
                        .disabled(!canSave)
                }
            }
            .onChange(of: name) { _ in
                applyCommonMaterialPriceIfNeeded()
            }
            .onChange(of: quantity) { _ in
                applyCommonMaterialPriceIfNeeded()
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(quantity) != nil &&
        Double(unitCost) != nil
    }

    private func save() {
        guard let q = Double(quantity),
              let u = Double(unitCost)
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let material: Material
        if case .edit(let existing) = mode {
            material = Material(
                id: existing.id,
                name: trimmedName,
                quantity: q,
                unitCost: u
            )
        } else {
            material = Material(
                name: trimmedName,
                quantity: q,
                unitCost: u
            )
        }

        onSave(material)
        dismiss()
    }

    private var modeTitle: String {
        switch mode {
        case .add: return "Add Material"
        case .edit: return "Edit Material"
        }
    }

    private func applyCommonMaterialPriceIfNeeded() {
        guard let price = settingsManager.commonMaterialPrice(for: name),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        if unitCost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            unitCost = String(format: "%.2f", price)
        }
    }
}

