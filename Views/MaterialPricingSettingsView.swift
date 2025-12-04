import SwiftUI

struct MaterialPricingSettingsView: View {
    @EnvironmentObject private var materialsStore: MaterialsCatalogStore

    @State private var overrideValues: [String: Double] = [:]
    @State private var productURLTexts: [String: String] = [:]
    @State private var newCustomName: String = ""
    @State private var newCustomUnit: String = ""
    @State private var newCustomPrice: String = ""
    @State private var newCustomCategoryName: String = ""
    @State private var newCustomCategory: MaterialCategory = MaterialCategory.allCases.first(where: { $0 != .custom }) ?? .paint
    @State private var showingAddMaterialSheet = false

    private var generatorMaterials: [MaterialItem] {
        let generator = JobMaterialGenerator(catalog: materialsStore)
        let ids = generator.allMaterialIDs()
        return ids.compactMap { materialsStore.material(withID: $0) }
    }

    private var groupedMaterials: [(category: String, items: [MaterialItem])] {
        let grouped = Dictionary(grouping: generatorMaterials, by: { $0.displayCategory })
        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key]?.sorted(by: { $0.name < $1.name }) else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        List {
            Section {
                Text("Customize the unit prices used when materials are generated from the templates above. Your overrides will be saved and applied every time the generator is used.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(groupedMaterials, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.items, id: \.id) { material in
                        MaterialPricingRow(
                            material: material,
                            price: priceBinding(for: material),
                            productURL: productURLBinding(for: material),
                            resetOverride: {
                                materialsStore.resetOverride(for: material.id)
                                overrideValues[material.id] = material.defaultUnitCost
                            },
                            deleteAction: { deleteMaterial(material) },
                            store: materialsStore
                        )
                    }
                }
            }
        }
        .navigationTitle("Material pricing")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddMaterialSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add generator material")
            }
        }
        .onAppear {
            syncOverrides()
            syncProductURLTexts()
        }
        .onChange(of: newCustomCategory, initial: false) { newValue in
            if newValue != .custom {
                newCustomCategoryName = ""
            }
        }
        .onChange(of: materialsStore.materials, initial: false) { _ in
            syncOverrides()
            syncProductURLTexts()
        }
        .sheet(isPresented: $showingAddMaterialSheet) {
            NavigationStack {
                Form {
                    Section("Add generator material") {
                        TextField("Name", text: $newCustomName)
                        TextField("Unit (each, tube, sq ft)", text: $newCustomUnit)
                        TextField("Unit cost", text: $newCustomPrice)
                            .keyboardType(.decimalPad)

                        Picker("Category", selection: $newCustomCategory) {
                            ForEach(MaterialCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(.menu)

                        if newCustomCategory == .custom {
                            TextField("Custom category name", text: $newCustomCategoryName)
                        }
                    }
                }
                .navigationTitle("New material")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            resetNewCustomMaterialForm()
                            showingAddMaterialSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addCustomMaterial()
                            showingAddMaterialSheet = false
                        }
                        .disabled(!canAddCustomMaterial)
                    }
                }
            }
        }
    }

    private func priceBinding(for material: MaterialItem) -> Binding<Double> {
        Binding(
            get: { overrideValues[material.id] ?? materialsStore.price(for: material) },
            set: { newValue in
                overrideValues[material.id] = newValue

                if newValue == material.defaultUnitCost {
                    materialsStore.resetOverride(for: material.id)
                } else {
                    materialsStore.setPriceOverride(newValue, for: material.id)
                }
            }
        )
    }

    private func syncOverrides() {
        var values: [String: Double] = [:]
        generatorMaterials.forEach { material in
            values[material.id] = materialsStore.price(for: material)
        }
        overrideValues = values
    }

    private func syncProductURLTexts() {
        var values: [String: String] = [:]
        generatorMaterials.forEach { material in
            values[material.id] = materialsStore.productURL(for: material)?.absoluteString ?? ""
        }
        productURLTexts = values
    }

    private func nameBinding(for material: MaterialItem) -> Binding<String> {
        Binding(
            get: { material.name },
            set: { newValue in
                materialsStore.updateCustomMaterial(material, name: newValue)
                syncOverrides()
            }
        )
    }

    private func unitBinding(for material: MaterialItem) -> Binding<String> {
        Binding(
            get: { material.unit },
            set: { newValue in
                materialsStore.updateCustomMaterial(material, unit: newValue)
                syncOverrides()
            }
        )
    }

    private func productURLBinding(for material: MaterialItem) -> Binding<String> {
        Binding(
            get: {
                productURLTexts[material.id] ?? materialsStore.productURL(for: material)?.absoluteString ?? ""
            },
            set: { newValue in
                productURLTexts[material.id] = newValue

                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    materialsStore.setProductURL(nil, for: material)
                    return
                }

                if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
                    materialsStore.setProductURL(url, for: material)
                }
            }
        )
    }

    private func categoryBinding(for material: MaterialItem) -> Binding<MaterialCategory> {
        Binding(
            get: { material.category },
            set: { newValue in
                let updatedCustomCategoryName = newValue == .custom ? material.customCategoryName : nil
                materialsStore.updateCustomMaterial(
                    material,
                    category: newValue,
                    customCategoryName: updatedCustomCategoryName
                )
                syncOverrides()
            }
        )
    }

    private func customCategoryNameBinding(for material: MaterialItem) -> Binding<String> {
        Binding(
            get: { material.customCategoryName ?? "" },
            set: { newValue in
                materialsStore.updateCustomMaterial(
                    material,
                    customCategoryName: newValue
                )
                syncOverrides()
            }
        )
    }

    private var canAddCustomMaterial: Bool {
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newCustomUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = Double(newCustomPrice.replacingOccurrences(of: ",", with: "."))
        let trimmedCustomCategoryName = newCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidCustomCategory = newCustomCategory != .custom || !trimmedCustomCategoryName.isEmpty

        return !trimmedName.isEmpty && !trimmedUnit.isEmpty && price != nil && hasValidCustomCategory
    }

    private func addCustomMaterial() {
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newCustomUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = Double(newCustomPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedCategoryName = newCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let customCategoryName = newCustomCategory == .custom ? trimmedCategoryName : nil
        let material = materialsStore.addCustomMaterial(
            name: trimmedName,
            unit: trimmedUnit,
            unitCost: price,
            category: newCustomCategory,
            customCategoryName: customCategoryName
        )
        overrideValues[material.id] = price

        resetNewCustomMaterialForm()
        syncOverrides()
    }

    private func resetNewCustomMaterialForm() {
        newCustomName = ""
        newCustomUnit = ""
        newCustomPrice = ""
        newCustomCategoryName = ""
        newCustomCategory = MaterialCategory.allCases.first(where: { $0 != .custom }) ?? .paint
    }

    private func deleteMaterial(_ material: MaterialItem) {
        materialsStore.deleteMaterial(material)
        overrideValues.removeValue(forKey: material.id)
        syncOverrides()
    }
}

private struct MaterialPricingRow: View {
    let material: MaterialItem
    let price: Binding<Double>
    let productURL: Binding<String>
    let resetOverride: () -> Void
    let deleteAction: () -> Void
    let store: MaterialsCatalogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            urlFields
            overrideButton
        }
        .padding(.vertical, 6)
        .swipeActions {
            Button(role: .destructive, action: deleteAction) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(material.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(material.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            TextField(
                "Unit cost",
                value: price,
                format: .currency(code: "USD")
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 140)
        }
    }

    private var urlFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Product URL (optional)", text: productURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption)
                .foregroundColor(.secondary)

            if let url = store.productURL(for: material) {
                Link("See Product Information", destination: url)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
            }
        }
    }

    private var overrideButton: some View {
        Group {
            if store.override(for: material.id) != nil {
                Button(action: resetOverride) {
                    Text("Reset to default \(material.defaultUnitCost.formatted(.currency(code: "USD")))")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
