import SwiftUI

struct MaterialEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let material: Material?
    let onSave: (Material) -> Void

    @State private var name: String
    @State private var quantityText: String
    @State private var unitCostText: String

    init(material: Material? = nil, onSave: @escaping (Material) -> Void) {
        self.material = material
        self.onSave = onSave

        _name = State(initialValue: material?.name ?? "")
        _quantityText = State(initialValue: material.map { String($0.quantity) } ?? "")
        _unitCostText = State(initialValue: material.map { String($0.unitCost) } ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Material")) {
                    TextField("Name", text: $name)
                }

                Section(header: Text("Details")) {
                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.decimalPad)
                    TextField("Unit cost", text: $unitCostText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(material == nil ? "Add Material" : "Edit Material")
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
            .onChange(of: quantityText) { _ in
                applyCommonMaterialPriceIfNeeded()
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(quantityText) != nil &&
        Double(unitCostText) != nil
    }

    private func save() {
        guard let quantity = Double(quantityText),
              let unitCost = Double(unitCostText) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let updatedMaterial = Material(
            id: material?.id ?? UUID(),
            name: trimmedName,
            quantity: quantity,
            unitCost: unitCost
        )

        onSave(updatedMaterial)
        dismiss()
    }

    private func applyCommonMaterialPriceIfNeeded() {
        guard let price = settingsManager.commonMaterialPrice(for: name),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        if unitCostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            unitCostText = String(format: "%.2f", price)
        }
    }
}
