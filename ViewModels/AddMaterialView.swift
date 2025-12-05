//
//  AddMaterialView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI
import FirebaseAuth

struct AddMaterialView: View {
    @Environment(\.dismiss) private var dismiss

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
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parseDouble(quantity) != nil &&
        parseDouble(unitCost) != nil
    }

    private func save() {
        guard let q = parseDouble(quantity),
              let u = parseDouble(unitCost),
              !name.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }

        let safeQuantity = debugCheckNaN(q, label: "material quantity")
        let safeUnitCost = debugCheckNaN(u, label: "material unit cost")

        let material = Material(
            ownerID: Auth.auth().currentUser?.uid ?? "",
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: safeQuantity,
            unitCost: safeUnitCost
        )

        onSave(material)
        dismiss()
    }
}

