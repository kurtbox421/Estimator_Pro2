import SwiftUI

struct MaterialGeneratorView: View {
    @EnvironmentObject private var jobVM: JobViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var materialsStore: MaterialsCatalogStore
    @EnvironmentObject private var materialInsights: MaterialIntelligenceStore
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroupIDs: Set<String> = []
    @State private var lengthText: String = ""
    @State private var secondaryText: String = ""
    @State private var suggestedMaterials: [MaterialRecommendation] = []
    @State private var isShowingEstimatePicker = false
    @State private var generated: [Material] = []
    @State private var validationMessage: String?
    @State private var selectedMaterialName: String?

    private var orderedGroups: [MaterialGroup] {
        materialsStore.materialGroups.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedGroups: [MaterialGroup] {
        orderedGroups.filter { selectedGroupIDs.contains($0.id) }
    }

    private var primarySelectedGroup: MaterialGroup? {
        if let selected = selectedGroups.first {
            return selected
        }
        return orderedGroups.first
    }

    private var selectedTemplate: MaterialGroupTemplateType {
        primarySelectedGroup?.templateType ?? .interiorWallBuild
    }

    var body: some View {
        Form {
            smartSuggestionsSection

            Section {
                let groups = orderedGroups

                WrappedLayout(spacing: 8) {
                    ForEach(groups) { group in
                        jobTypeChip(for: group)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                VStack(spacing: 4) {
                    Text("BETA")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Text("JOB TYPE")
                            .font(.headline)

                        Spacer()

                        Button("Clear") {
                            selectedGroupIDs.removeAll()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .disabled(selectedGroupIDs.isEmpty)
                    }
                    .padding(.top, 2)
                }
            }

            Section("WALL DIMENSIONS (FT)") {
                TextField("Length", text: $lengthText)
                    .keyboardType(.decimalPad)
                TextField(
                    secondaryPlaceholder,
                    text: $secondaryText
                )
                .keyboardType(.decimalPad)
            }

            Button("Generate Materials") {
                Task {
                    await generateMaterials()
                }
            }
            .disabled(selectedGroupIDs.isEmpty)

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            if !generated.isEmpty {
                Section("Suggested Materials") {
                    ForEach(generated) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)

                            Text("\(String(format: "%.2f", item.quantity)) \(item.unit ?? "")")
                            if item.unitCost > 0 {
                                Text("Est. unit cost: \(safeNumber(item.unitCost).formatted(.currency(code: "USD")))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let notes = item.notes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMaterialName = item.name
                        }
                    }
                }
            }

            if !suggestedMaterials.isEmpty {
                Section(header: Text("WHAT'S NEXT?")) {
                    Button(action: createNewEstimateFromSuggestedMaterials) {
                        Text("Create New Estimate")
                            .frame(maxWidth: .infinity)
                    }

                    Button(action: { isShowingEstimatePicker = true }) {
                        Text("Add to Existing Estimate")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Material Generator")
        .sheet(isPresented: $isShowingEstimatePicker) {
            NavigationView {
                List {
                    ForEach(jobVM.jobs) { job in
                        Button {
                            addSuggestedMaterials(to: job)
                            isShowingEstimatePicker = false
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(job.name)
                                Text(job.category)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Choose Estimate")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingEstimatePicker = false }
                    }
                }
            }
        }
        .onChange(of: lengthText) { _, _ in regenerateAfterDimensionChange() }
        .onChange(of: secondaryText) { _, _ in regenerateAfterDimensionChange() }
        .onChange(of: selectedGroupIDs) { _, _ in
            if selectedGroupIDs.isEmpty {
                validationMessage = nil
                suggestedMaterials = []
                generated = []
                selectedMaterialName = nil
            } else {
                regenerateAfterDimensionChange()
            }
        }
    }

    private var smartSuggestionsSection: some View {
        let frequent = materialInsights.frequentlyUsedMaterials(limit: 6)
        let jobSpecific = materialInsights.materials(forJobType: selectedTemplate.displayName, limit: 6)
        let paired = selectedMaterialName.flatMap { materialInsights.commonlyUsed(withMaterialName: $0, limit: 6) } ?? []

        return Section("SMART SUGGESTIONS") {
            if frequent.isEmpty, jobSpecific.isEmpty, paired.isEmpty {
                Text("Suggestions will appear here once you have materials saved in your jobs or invoices.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if !frequent.isEmpty {
                suggestionGroup(title: "Frequently used", stats: frequent)
            }

            if !jobSpecific.isEmpty {
                suggestionGroup(title: "Suggested for \(selectedTemplate.displayName)", stats: jobSpecific)
            }

            if !paired.isEmpty {
                suggestionGroup(title: "Commonly paired", stats: paired)
            }
        }
    }

    private func jobTypeChip(for group: MaterialGroup) -> some View {
        let isSelected = selectedGroupIDs.contains(group.id)

        return Button {
            if isSelected {
                selectedGroupIDs.remove(group.id)
            } else {
                selectedGroupIDs.insert(group.id)
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }

                Text(group.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func suggestionGroup(title: String, stats: [MaterialUsageStats]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stats) { stat in
                        suggestionChip(for: stat)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func suggestionChip(for stat: MaterialUsageStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stat.name)
                .font(.headline)
                .lineLimit(2)

            if let avgCost = stat.averageUnitCost {
                Text("Avg unit cost: \(safeNumber(avgCost).formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let avgQty = stat.averageQuantity {
                Text("Avg qty: \(String(format: "%.2f", safeNumber(avgQty))) \(stat.mostCommonUnit ?? "units")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                applySuggestion(from: stat)
            } label: {
                Text("Use")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private var secondaryPlaceholder: String {
        switch selectedTemplate {
        case .interiorWallBuild:
            return "Height"
        case .lvpFlooring:
            return "Width"
        case .paintRoom:
            return "Width"
        case .basicBathroomRemodel:
            return "Width"
        case .exteriorPaint:
            return "Width"
        case .tileBacksplash:
            return "Height"
        case .deckBuild:
            return "Width"
        case .roofShingleReplacement:
            return "Width"
        }
    }

    @MainActor
    private func generateMaterials() async {
        let length = parseDouble(lengthText)
        let secondary = parseDouble(secondaryText)

        guard !selectedGroups.isEmpty else {
            validationMessage = "Select at least one job type."
            generated = []
            suggestedMaterials = []
            return
        }

        guard length != nil || secondary != nil else {
            validationMessage = "Enter at least one dimension."
            generated = []
            suggestedMaterials = []
            return
        }

        guard selectedGroups.allSatisfy({ !materialsStore.items(inGroupID: $0.id).isEmpty }) else {
            validationMessage = "Add materials in Material Pricing to create job types."
            generated = []
            suggestedMaterials = []
            return
        }

        validationMessage = nil
        let catalogSnapshot = await MainActor.run { materialsStore.snapshot() }

        let recommendations = selectedGroups.flatMap { group in
            let context = JobContext(
                jobType: group.templateType.jobType,
                lengthFeet: length,
                secondaryFeet: secondary,
                heightFeet: nil,
                areaSqFt: nil,
                doorCount: 0,
                windowCount: 0,
                coats: 2,
                includesCeiling: true,
                wasteFactor: 0.1,
                notes: nil
            )

            return MaterialsRecommender(catalog: materialsStore)
                .recommendMaterials(for: group, context: context)
        }
        let mergedRecommendations = mergeRecommendations(recommendations)
        suggestedMaterials = mergedRecommendations
        debugGuardForGroupConsistency(mergedRecommendations, selectedGroupIDs: selectedGroupIDs)
        generated = mergedRecommendations.map { materialFromRecommendation($0, catalog: catalogSnapshot) }
        selectedMaterialName = mergedRecommendations.first?.name
    }

    private func regenerateAfterDimensionChange() {
        guard !suggestedMaterials.isEmpty || !generated.isEmpty else {
            validationMessage = nil
            return
        }
        Task {
            await generateMaterials()
        }
    }

    private func materialFromRecommendation(
        _ rec: MaterialRecommendation,
        catalog: MaterialsCatalogSnapshot
    ) -> Material {
        MaterialResolutionHelper.material(
            from: rec,
            catalog: catalog,
            ownerID: session.uid ?? "",
            fallbackUnitCost: settingsManager.commonMaterialPrice(for: rec.name)
        )
    }

    private func applySuggestion(from stats: MaterialUsageStats) {
        Task {
            await applySuggestionAsync(from: stats)
        }
    }

    @MainActor
    private func applySuggestionAsync(from stats: MaterialUsageStats) async {
        let recommendation = recommendation(from: stats)
        suggestedMaterials.append(recommendation)
        let catalogSnapshot = await MainActor.run { materialsStore.snapshot() }
        generated = makeEstimateMaterials(from: suggestedMaterials, catalog: catalogSnapshot)
        selectedMaterialName = stats.name
    }

    private func recommendation(from stats: MaterialUsageStats) -> MaterialRecommendation {
        let suggestedQuantity = stats.averageQuantity.map { safeNumber($0) } ?? 1
        let unit = stats.mostCommonUnit ?? "unit"
        let note = "Suggested from your history"

        return MaterialRecommendation(
            name: stats.name,
            quantity: suggestedQuantity,
            unit: unit,
            category: "Smart suggestion",
            notes: note,
            sourceGroupID: primarySelectedGroup?.id ?? "",
            estimatedUnitCost: stats.averageUnitCost.map { safeNumber($0) }
        )
    }

    private func makeEstimateMaterials(
        from recs: [MaterialRecommendation],
        catalog: MaterialsCatalogSnapshot
    ) -> [Material] {
        recs.map { materialFromRecommendation($0, catalog: catalog) }
    }

    private func mergeRecommendations(_ recs: [MaterialRecommendation]) -> [MaterialRecommendation] {
        struct RecommendationKey: Hashable {
            let name: String
            let unit: String
        }

        struct RecommendationAccumulator {
            var name: String
            var unit: String
            var category: String
            var notes: String?
            var sourceGroupID: String
            var quantity: Double
            var estimatedUnitCost: Double?
        }

        var merged: [RecommendationKey: RecommendationAccumulator] = [:]

        for rec in recs {
            let key = RecommendationKey(
                name: rec.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                unit: rec.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )

            if var existing = merged[key] {
                existing.quantity += rec.quantity
                if existing.estimatedUnitCost == nil {
                    existing.estimatedUnitCost = rec.estimatedUnitCost
                }
                if existing.notes == nil {
                    existing.notes = rec.notes
                }
                merged[key] = existing
            } else {
                merged[key] = RecommendationAccumulator(
                    name: rec.name,
                    unit: rec.unit,
                    category: rec.category,
                    notes: rec.notes,
                    sourceGroupID: rec.sourceGroupID,
                    quantity: rec.quantity,
                    estimatedUnitCost: rec.estimatedUnitCost
                )
            }
        }

        return merged.values
            .sorted { $0.name < $1.name }
            .map { accumulator in
                MaterialRecommendation(
                    name: accumulator.name,
                    quantity: accumulator.quantity,
                    unit: accumulator.unit,
                    category: accumulator.category,
                    notes: accumulator.notes,
                    sourceGroupID: accumulator.sourceGroupID,
                    estimatedUnitCost: accumulator.estimatedUnitCost
                )
            }
    }

    private func createNewEstimateFromSuggestedMaterials() {
        Task {
            await createNewEstimateFromSuggestedMaterialsAsync()
        }
    }

    @MainActor
    private func createNewEstimateFromSuggestedMaterialsAsync() async {
        let catalogSnapshot = await MainActor.run { materialsStore.snapshot() }
        let materials = makeEstimateMaterials(from: suggestedMaterials, catalog: catalogSnapshot)
        let jobType = primarySelectedGroup?.templateType.jobType ?? selectedTemplate.jobType
        _ = jobVM.createEstimate(from: materials, jobType: jobType)
        dismiss()
    }

    private func addSuggestedMaterials(to job: Job) {
        Task {
            await addSuggestedMaterialsAsync(to: job)
        }
    }

    @MainActor
    private func addSuggestedMaterialsAsync(to job: Job) async {
        let catalogSnapshot = await MainActor.run { materialsStore.snapshot() }
        let materials = makeEstimateMaterials(from: suggestedMaterials, catalog: catalogSnapshot)
        jobVM.appendMaterials(materials, to: job.id)
    }

    private func debugGuardForGroupConsistency(_ recommendations: [MaterialRecommendation], selectedGroupIDs: Set<String>) {
        let invalid = recommendations.filter { !selectedGroupIDs.contains($0.sourceGroupID) }
        if !invalid.isEmpty {
            print("❌ Generator leakage: selectedGroupIDs=\(selectedGroupIDs)")
            invalid.forEach { item in
                print("  - \(item.name) sourceGroupID=\(item.sourceGroupID)")
            }
            assertionFailure("Suggested materials include items not in selected groups")
        }
    }
}

private struct WrappedLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth == 0 ? 0 : spacing) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth)

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
