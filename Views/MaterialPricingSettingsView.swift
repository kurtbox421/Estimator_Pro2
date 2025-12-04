import SwiftUI

struct MaterialPricingSettingsView: View {
    @EnvironmentObject private var materialsStore: MaterialsCatalogStore

    @State private var overrideValues: [String: Double] = [:]
    @State private var newCustomName: String = ""
    @State private var newCustomUnit: String = ""
    @State private var newCustomPrice: String = ""

    private var generatorMaterials: [MaterialItem] {
        let generator = JobMaterialGenerator(catalog: materialsStore)
        let ids = generator.allMaterialIDs()
        return ids.compactMap { materialsStore.material(withID: $0) }
            .sorted { lhs, rhs in
                if lhs.displayCategory != rhs.displayCategory {
                    return lhs.displayCategory < rhs.displayCategory
                }
                return lhs.name < rhs.name
            }
    }

    private var groupedMaterials: [(category: String, items: [MaterialItem])] {
        let grouped = Dictionary(grouping: generatorMaterials, by: { $0.displayCategory })
        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key] else { return nil }
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

            Section("Custom generator materials") {
                Text("Add materials that should always be suggested when you run the generator. Set their unit and default price to have them included alongside the built-in items.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)

                ForEach(materialsStore.customMaterials, id: \.id) { material in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Material name", text: nameBinding(for: material))
                                    .font(.subheadline.weight(.semibold))

                                TextField("Unit (ex: each, tube, sq ft)", text: unitBinding(for: material))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            TextField(
                                "Unit cost",
                                value: priceBinding(for: material),
                                format: .currency(code: "USD")
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                        }

                        if materialsStore.override(for: material.id) != nil {
                            Button {
                                materialsStore.resetOverride(for: material.id)
                                overrideValues[material.id] = material.defaultUnitCost
                            } label: {
                                Text("Reset to default \(material.defaultUnitCost.formatted(.currency(code: "USD")))")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: deleteCustomMaterials)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add material")
                        .font(.subheadline.weight(.semibold))

                    TextField("Name", text: $newCustomName)
                    TextField("Unit (each, tube, sq ft)", text: $newCustomUnit)
                    TextField("Unit cost", text: $newCustomPrice)
                        .keyboardType(.decimalPad)

                    Button {
                        addCustomMaterial()
                    } label: {
                        Label("Add to generator", systemImage: "plus.circle.fill")
                    }
                    .disabled(!canAddCustomMaterial)
                }
                .padding(.vertical, 4)
            }

            ForEach(groupedMaterials, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.items, id: \.id) { material in
                        VStack(alignment: .leading, spacing: 6) {
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
                                    value: priceBinding(for: material),
                                    format: .currency(code: "USD")
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                            }

                            if materialsStore.override(for: material.id) != nil {
                                Button {
                                    materialsStore.resetOverride(for: material.id)
                                    overrideValues[material.id] = material.defaultUnitCost
                                } label: {
                                    Text("Reset to default \(material.defaultUnitCost.formatted(.currency(code: "USD")))")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Material pricing")
        .onAppear(perform: syncOverrides)
        .onChange(of: materialsStore.materials) { _ in syncOverrides() }
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
        materialsStore.customMaterials.forEach { material in
            values[material.id] = materialsStore.price(for: material)
        }
        overrideValues = values
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

    private var canAddCustomMaterial: Bool {
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newCustomUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = Double(newCustomPrice.replacingOccurrences(of: ",", with: "."))
        return !trimmedName.isEmpty && !trimmedUnit.isEmpty && price != nil
    }

    private func addCustomMaterial() {
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newCustomUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = Double(newCustomPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let material = materialsStore.addCustomMaterial(name: trimmedName, unit: trimmedUnit, unitCost: price)
        overrideValues[material.id] = price

        newCustomName = ""
        newCustomUnit = ""
        newCustomPrice = ""
        syncOverrides()
    }

    private func deleteCustomMaterials(at offsets: IndexSet) {
        offsets.forEach { index in
            guard materialsStore.customMaterials.indices.contains(index) else { return }
            let material = materialsStore.customMaterials[index]
            materialsStore.deleteCustomMaterial(material)
            overrideValues.removeValue(forKey: material.id)
        }
        syncOverrides()
    }
}
