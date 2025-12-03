import SwiftUI

struct MaterialPricingSettingsView: View {
    @EnvironmentObject private var materialsStore: MaterialsCatalogStore

    @State private var overrideValues: [String: Double] = [:]

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
}
