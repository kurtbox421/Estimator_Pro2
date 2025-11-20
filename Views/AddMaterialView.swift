//
//  AddMaterialView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

struct AddMaterialView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    var onSave: (Material) -> Void

    @State private var name = ""
    @State private var quantity = ""
    @State private var unitCost = ""

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
            .navigationTitle("Add Material")
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

        let material = Material(
            name: trimmedName,
            quantity: q,
            unitCost: u
        )

        onSave(material)
        dismiss()
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

