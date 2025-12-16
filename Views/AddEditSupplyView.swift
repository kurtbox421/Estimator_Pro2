import SwiftUI

struct AddEditSupplyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var unit: String
    @State private var onHand: Double
    @State private var lowStockThreshold: Double?

    let supply: SupplyItem?
    let onSave: (SupplyItem) -> Void

    init(supply: SupplyItem?, onSave: @escaping (SupplyItem) -> Void) {
        self.supply = supply
        self.onSave = onSave

        _name = State(initialValue: supply?.name ?? "")
        _unit = State(initialValue: supply?.unit ?? "")
        _onHand = State(initialValue: supply?.onHand ?? 0)
        _lowStockThreshold = State(initialValue: supply?.lowStockThreshold)
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                TextField("Unit (e.g. pcs, ft)", text: $unit)
                HStack {
                    Text("On hand")
                    Spacer()
                    TextField("0", value: $onHand, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Low stock threshold")
                    Spacer()
                    TextField("Optional", value: Binding(
                        get: { lowStockThreshold ?? 0 },
                        set: { newValue in
                            lowStockThreshold = newValue == 0 ? nil : newValue
                        }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle(supply == nil ? "Add Supply" : "Edit Supply")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!isValid)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !unit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        var item = supply ?? SupplyItem()
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.unit = unit.trimmingCharacters(in: .whitespaces)
        item.onHand = onHand
        item.lowStockThreshold = lowStockThreshold
        item.updatedAt = Date()
        if item.createdAt > item.updatedAt { item.createdAt = Date() }
        onSave(item)
        dismiss()
    }
}
