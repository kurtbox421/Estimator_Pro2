import SwiftUI

struct MaterialPricingSettingsView: View {
    @EnvironmentObject private var materialsStore: MaterialsCatalogStore

    @State private var overrideValues: [String: Double] = [:]
    @State private var productURLTexts: [String: String] = [:]
    @State private var expandedMaterialIDs: Set<String> = []
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

    private var groupedMaterials: [(group: MaterialGroup, items: [MaterialItem])] {
        materialsStore.materialGroups
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { group in
                (group, materialsStore.materials(in: group))
            }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.49, green: 0.38, blue: 1.0),
                    Color(red: 0.25, green: 0.28, blue: 0.60)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    RoundedCard {
                        Text("Customize the unit prices used when materials are generated from the templates above. Your overrides will be saved and applied every time the generator is used.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: 720)

                    ForEach(groupedMaterials, id: \.group.id) { group in
                        MaterialPricingSection(
                            title: group.group.name,
                            materials: group.items,
                            store: materialsStore,
                            expandedMaterialIDs: $expandedMaterialIDs,
                            priceBinding: priceBinding,
                            productURLBinding: productURLBinding,
                            onEdit: startEditing,
                            onDelete: { material in
                                deleteTarget = material
                                isShowingDeleteConfirm = true
                            },
                            onResetOverride: { material in
                                materialsStore.resetOverride(for: material.id)
                                overrideValues[material.id] = material.defaultUnitCost
                            }
                        )
                        .id(group.group.id)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .scrollDismissesKeyboard(.interactively)
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
        }
        .onChange(of: newCustomCategory) { _, newValue in
            if newValue != .custom {
                newCustomCategoryName = ""
            }
        }
        .onChange(of: materialsStore.materials) { _, _ in
            syncOverrides()
            syncProductURLTexts()
        }
        .sheet(isPresented: $showingMaterialSheet) {
            NavigationStack {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.38, blue: 1.0),
                            Color(red: 0.25, green: 0.28, blue: 0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 24) {
                            RoundedCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(editTarget == nil ? "Add generator material" : "Edit generator material")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    VStack(spacing: 0) {
                                        materialField("Name", text: $newCustomName)
                                            .textInputAutocapitalization(.words)

                                        Divider().overlay(Color.white.opacity(0.12))

                                        materialField("Unit (each, tube, sq ft)", text: $newCustomUnit)
                                            .textInputAutocapitalization(.words)

                                        Divider().overlay(Color.white.opacity(0.12))

                                        materialField("Unit cost", text: $newCustomPrice)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.decimalPad)
                                    }

                                    materialField("Product URL (optional)", text: $newCustomProductURL)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()

                                    Picker("Category", selection: $newCustomCategory) {
                                        ForEach(MaterialCategory.allCases) { category in
                                            Text(category.displayName).tag(category)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.white)

                                    if newCustomCategory == .custom {
                                        materialField("Custom category name", text: $newCustomCategoryName)
                                            .textInputAutocapitalization(.words)
                                    }
                                }
                            }
                            .frame(maxWidth: 640)

                            RoundedCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Coverage (optional)")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    VStack(spacing: 0) {
                                        materialField("Coverage amount", text: $newCustomCoverageQuantity)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.decimalPad)

                                        Divider().overlay(Color.white.opacity(0.12))

                                        Picker("Coverage unit", selection: $newCustomCoverageUnit) {
                                            Text("Sq ft").tag("sqft")
                                            Text("Linear ft").tag("lf")
                                            Text("Each").tag("each")
                                        }
                                        .pickerStyle(.menu)
                                        .tint(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .frame(height: 52)

                                        Divider().overlay(Color.white.opacity(0.12))

                                        materialField("Waste %", text: $newCustomWastePercent)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.decimalPad)
                                    }
                                }
                            }
                            .frame(maxWidth: 640)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
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

    private func materialField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.body)
            .foregroundColor(.white)
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

private struct MaterialPricingSection: View {
    let title: String
    let materials: [MaterialItem]
    let store: MaterialsCatalogStore
    @Binding var expandedMaterialIDs: Set<String>
    let priceBinding: (MaterialItem) -> Binding<Double>
    let productURLBinding: (MaterialItem) -> Binding<String>
    let onEdit: (MaterialItem) -> Void
    let onDelete: (MaterialItem) -> Void
    let onResetOverride: (MaterialItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .padding(.horizontal, 8)

            RoundedCard {
                VStack(spacing: 0) {
                    ForEach(Array(materials.enumerated()), id: \.element.id) { index, material in
                        MaterialPricingRow(
                            material: material,
                            price: priceBinding(material),
                            productURL: productURLBinding(material),
                            resetOverride: { onResetOverride(material) },
                            onEdit: { onEdit(material) },
                            onDelete: { onDelete(material) },
                            store: store,
                            isExpanded: Binding(
                                get: { expandedMaterialIDs.contains(material.id) },
                                set: { newValue in
                                    if newValue {
                                        expandedMaterialIDs.insert(material.id)
                                    } else {
                                        expandedMaterialIDs.remove(material.id)
                                    }
                                }
                            )
                        )

                        if index != materials.count - 1 {
                            Divider().overlay(Color.white.opacity(0.12))
                        }
                    }
                }
            }
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity)
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
    @Binding var isExpanded: Bool

    @State private var priceText: String = ""
    @State private var validationMessage: String?
    @FocusState private var isPriceFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                editFields
            } else if let url = store.productURL(for: material) {
                Link("Product link", destination: url)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 12)
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                priceText = formattedNumber(price.wrappedValue)
                validationMessage = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(material.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)

                        Text(material.unit)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Text(price.wrappedValue.formatted(.currency(code: "USD")))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button(action: onEdit) {
                    Label("Edit details", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 6)
            }
        }
    }

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("Price")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))

                TextField("Unit cost", text: $priceText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .focused($isPriceFocused)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .tint(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                Spacer()

                Button("Save") {
                    savePrice()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                )
                .foregroundColor(.white)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.85))
            }

            TextField("Product URL (optional)", text: productURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            if let url = store.productURL(for: material) {
                Link("See product information", destination: url)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }

            if store.override(for: material.id) != nil {
                Button(action: resetOverride) {
                    Text("Reset to default \(material.defaultUnitCost.formatted(.currency(code: "USD")))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func savePrice() {
        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
        guard let parsed = parseDouble(normalized) else {
            validationMessage = "Enter a valid price."
            return
        }

        price.wrappedValue = parsed
        priceText = formattedNumber(parsed)
        validationMessage = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
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
