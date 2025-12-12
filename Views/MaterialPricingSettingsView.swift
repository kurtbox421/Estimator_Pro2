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
    @State private var newCustomProductURL: String = ""
    @State private var newCustomCoverageQuantity: String = ""
    @State private var newCustomCoverageUnit: String = "sqft"
    @State private var newCustomWastePercent: String = ""
    @State private var showingMaterialSheet = false
    @State private var editTarget: MaterialItem?
    @State private var deleteTarget: MaterialItem?
    @State private var isShowingDeleteConfirm = false
    @State private var selectedTemplate: MaterialGroupTemplateType?

    private var groupedMaterials: [(category: String, items: [MaterialItem])] {
        filteredGroups.map { group in
            (group.name, materialsStore.materials(in: group))
        }
    }

    private var availableTemplates: [MaterialGroupTemplateType] {
        Array(Set(materialsStore.materialGroups.map { $0.templateType }))
            .sorted { $0.displayName < $1.displayName }
    }

    private var filteredGroups: [MaterialGroup] {
        let groups = materialsStore.materialGroups.sorted { $0.sortOrder < $1.sortOrder }
        guard let selectedTemplate else { return groups }
        return groups.filter { $0.templateType == selectedTemplate }
    }

    var body: some View {
        List {
            if !availableTemplates.isEmpty {
                Section("Job type") {
                    Picker("Job type", selection: $selectedTemplate) {
                        ForEach(availableTemplates) { template in
                            Text(template.displayName).tag(Optional.some(template))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

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
                            onEdit: { startEditing(material) },
                            onDelete: {
                                deleteTarget = material
                                isShowingDeleteConfirm = true
                            },
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
                    startAddingMaterial()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add generator material")
            }
        }
        .onAppear {
            syncOverrides()
            syncProductURLTexts()
            if selectedTemplate == nil {
                selectedTemplate = availableTemplates.first
            }
        }
        .onChange(of: newCustomCategory, initial: false) { _, newValue in
            if newValue != .custom {
                newCustomCategoryName = ""
            }
        }
        .onChange(of: materialsStore.materials, initial: false) { _, _ in
            syncOverrides()
            syncProductURLTexts()
            if let selectedTemplate, !availableTemplates.contains(selectedTemplate) {
                self.selectedTemplate = availableTemplates.first
            }
        }
        .sheet(isPresented: $showingMaterialSheet) {
            NavigationStack {
                Form {
                    Section(editTarget == nil ? "Add generator material" : "Edit generator material") {
                        TextField("Name", text: $newCustomName)
                        TextField("Unit (each, tube, sq ft)", text: $newCustomUnit)
                        TextField("Unit cost", text: $newCustomPrice)
                            .keyboardType(.decimalPad)

                        TextField("Product URL (optional)", text: $newCustomProductURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

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

                    Section("Coverage (optional)") {
                        TextField("Coverage amount", text: $newCustomCoverageQuantity)
                            .keyboardType(.decimalPad)

                        Picker("Coverage unit", selection: $newCustomCoverageUnit) {
                            Text("Sq ft").tag("sqft")
                            Text("Linear ft").tag("lf")
                            Text("Each").tag("each")
                        }
                        .pickerStyle(.menu)

                        TextField("Waste %", text: $newCustomWastePercent)
                            .keyboardType(.decimalPad)
                    }
                }
                .navigationTitle(editTarget == nil ? "New material" : "Edit material")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            resetNewCustomMaterialForm()
                            editTarget = nil
                            showingMaterialSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editTarget == nil ? "Add" : "Save") {
                            if let editTarget {
                                updateMaterial(editTarget)
                            } else {
                                addCustomMaterial()
                            }
                            editTarget = nil
                            showingMaterialSheet = false
                        }
                        .disabled(!canAddCustomMaterial)
                    }
                }
            }
        }
        .alert("Delete material?", isPresented: $isShowingDeleteConfirm, presenting: deleteTarget) { _ in
            Button("Delete", role: .destructive) {
                if let deleteTarget {
                    deleteMaterial(deleteTarget)
                }
                self.deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
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
        materialsStore.materials.forEach { material in
            values[material.id] = materialsStore.price(for: material)
        }
        overrideValues = values
    }

    private func syncProductURLTexts() {
        var values: [String: String] = [:]
        materialsStore.materials.forEach { material in
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
        let price = parseDouble(newCustomPrice.replacingOccurrences(of: ",", with: "."))
        let trimmedCustomCategoryName = newCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidCustomCategory = newCustomCategory != .custom || !trimmedCustomCategoryName.isEmpty
        let coverageQuantity = parseDouble(newCustomCoverageQuantity.replacingOccurrences(of: ",", with: "."))
        let hasValidCoverage = coverageQuantity == nil || !newCustomCoverageUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let trimmedProductURL = newCustomProductURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValidURL = trimmedProductURL.isEmpty || URL(string: trimmedProductURL)?.scheme != nil

        return !trimmedName.isEmpty && !trimmedUnit.isEmpty && price != nil && hasValidCustomCategory && hasValidCoverage && isValidURL
    }

    private func addCustomMaterial() {
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newCustomUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = debugCheckNaN(parseDouble(newCustomPrice.replacingOccurrences(of: ",", with: ".")) ?? 0, label: "custom material price")
        let trimmedCategoryName = newCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let customCategoryName = newCustomCategory == .custom ? trimmedCategoryName : nil
        let trimmedProductURL = newCustomProductURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let productURL = URL(string: trimmedProductURL)
        let coverageQuantity = parseDouble(newCustomCoverageQuantity.replacingOccurrences(of: ",", with: "."))
        let wastePercent = parseDouble(newCustomWastePercent.replacingOccurrences(of: ",", with: ".")) ?? 0
        let wasteFactor = debugCheckNaN(wastePercent / 100, label: "custom material waste factor")
        let material = materialsStore.addCustomMaterial(
            name: trimmedName,
            unit: trimmedUnit,
            unitCost: price,
            category: newCustomCategory,
            customCategoryName: customCategoryName,
            productURL: productURL,
            coverageQuantity: coverageQuantity,
            coverageUnit: coverageQuantity != nil ? newCustomCoverageUnit : nil,
            wasteFactor: wasteFactor
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
        newCustomProductURL = ""
        newCustomCoverageQuantity = ""
        newCustomCoverageUnit = "sqft"
        newCustomWastePercent = ""
    }

    private func startAddingMaterial() {
        resetNewCustomMaterialForm()
        editTarget = nil
        showingMaterialSheet = true
    }

    private func startEditing(_ material: MaterialItem) {
        editTarget = material
        newCustomName = material.name
        newCustomUnit = material.unit
        newCustomPrice = formattedNumber(material.defaultUnitCost)
        newCustomCategory = material.category
        newCustomCategoryName = material.customCategoryName ?? ""
        newCustomProductURL = material.productURL?.absoluteString ?? ""
        newCustomCoverageQuantity = formattedNumber(material.coverageQuantity)
        newCustomCoverageUnit = material.coverageUnit ?? "sqft"
        newCustomWastePercent = formattedNumber(material.wasteFactor * 100)
        showingMaterialSheet = true
    }

    private func deleteMaterial(_ material: MaterialItem) {
        materialsStore.deleteMaterial(material)
        overrideValues.removeValue(forKey: material.id)
        syncOverrides()
    }

    private func updateMaterial(_ material: MaterialItem) {
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newCustomUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = debugCheckNaN(parseDouble(newCustomPrice.replacingOccurrences(of: ",", with: ".")) ?? material.defaultUnitCost, label: "custom material price")
        let trimmedCategoryName = newCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let customCategoryName = newCustomCategory == .custom ? trimmedCategoryName : nil
        let trimmedProductURL = newCustomProductURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let productURL = trimmedProductURL.isEmpty ? nil : URL(string: trimmedProductURL)
        let coverageQuantity = parseDouble(newCustomCoverageQuantity.replacingOccurrences(of: ",", with: "."))
        let wastePercent = parseDouble(newCustomWastePercent.replacingOccurrences(of: ",", with: ".")) ?? 0
        let wasteFactor = debugCheckNaN(wastePercent / 100, label: "custom material waste factor")

        materialsStore.updateCustomMaterial(
            material,
            name: trimmedName,
            unit: trimmedUnit,
            defaultUnitCost: price,
            category: newCustomCategory,
            customCategoryName: customCategoryName,
            productURL: productURL,
            coverageQuantity: coverageQuantity,
            coverageUnit: coverageQuantity != nil ? newCustomCoverageUnit : nil,
            wasteFactor: wasteFactor
        )

        overrideValues[material.id] = price
        syncOverrides()
        syncProductURLTexts()
    }

    private func formattedNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
}

private struct MaterialPricingRow: View {
    let material: MaterialItem
    let price: Binding<Double>
    let productURL: Binding<String>
    let resetOverride: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let store: MaterialsCatalogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            urlFields
            overrideButton
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
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
