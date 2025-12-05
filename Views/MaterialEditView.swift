import SwiftUI
import FirebaseAuth

struct MaterialEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let material: Material?
    let onSave: (Material) -> Void

    @State private var name: String
    @State private var quantityText: String
    @State private var unitCostText: String
    @State private var productURLText: String

    init(material: Material? = nil, onSave: @escaping (Material) -> Void) {
        self.material = material
        self.onSave = onSave

        _name = State(initialValue: material?.name ?? "")
        _quantityText = State(initialValue: material.map { String($0.quantity) } ?? "")
        _unitCostText = State(initialValue: material.map { String($0.unitCost) } ?? "")
        _productURLText = State(initialValue: material?.productURL?.absoluteString ?? "")
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
                    TextField("Product URL (optional)", text: $productURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
            .onChange(of: name, initial: false) { _, _ in
                applyCommonMaterialPriceIfNeeded()
            }
            .onChange(of: quantityText, initial: false) { _, _ in
                applyCommonMaterialPriceIfNeeded()
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parseDouble(quantityText) != nil &&
        parseDouble(unitCostText) != nil &&
        isValidProductURLText(productURLText)
    }

    private func save() {
        guard let quantityValue = parseDouble(quantityText),
              let unitCostValue = parseDouble(unitCostText) else { return }

        let quantity = debugCheckNaN(quantityValue, label: "material quantity")
        let unitCost = debugCheckNaN(unitCostValue, label: "material unit cost")

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let productURL = parsedURL(from: productURLText)

        let updatedMaterial = Material(
            id: material?.id ?? UUID(),
            ownerID: material?.ownerID ?? (Auth.auth().currentUser?.uid ?? ""),
            name: trimmedName,
            quantity: quantity,
            unitCost: unitCost,
            productURL: productURL
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

    private func isValidProductURLText(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return parsedURL(from: text) != nil
    }

    private func parsedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        return url
    }
}
