import SwiftUI
import FirebaseAuth

struct MaterialGeneratorView: View {
    @EnvironmentObject private var jobVM: JobViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var materialsStore: MaterialsCatalogStore
    @EnvironmentObject private var materialInsights: MaterialIntelligenceStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedJobType: MaterialJobType = .interiorWallBuild
    @State private var lengthText: String = ""
    @State private var secondaryText: String = ""
    @State private var suggestedMaterials: [MaterialRecommendation] = []
    @State private var isShowingEstimatePicker = false
    @State private var generated: [Material] = []
    @State private var validationMessage: String?
    @State private var selectedMaterialName: String?

    var body: some View {
        Form {
            smartSuggestionsSection

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MaterialJobType.allCases) { type in
                            Button {
                                selectedJobType = type
                            } label: {
                                Text(type.displayName)
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        selectedJobType == type
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedJobType == type
                                                ? Color.accentColor
                                                : Color.secondary.opacity(0.4),
                                                lineWidth: 1
                                            )
                                    )
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                VStack(spacing: 4) {
                    Text("Beta")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)

                    Text("JOB TYPE")
                        .font(.headline)
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
                generateMaterials()
            }

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
    }

    private var smartSuggestionsSection: some View {
        let frequent = materialInsights.frequentlyUsedMaterials(limit: 6)
        let jobSpecific = materialInsights.materials(forJobType: selectedJobType.displayName, limit: 6)
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
                suggestionGroup(title: "Suggested for \(selectedJobType.displayName)", stats: jobSpecific)
            }

            if !paired.isEmpty {
                suggestionGroup(title: "Commonly paired", stats: paired)
            }
        }
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
        switch selectedJobType {
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

    private func generateMaterials() {
        let length = parseDouble(lengthText)
        let secondary = parseDouble(secondaryText)

        guard length != nil || secondary != nil else {
            validationMessage = "Enter at least one dimension."
            generated = []
            suggestedMaterials = []
            return
        }

        validationMessage = nil

        let context = JobContext(
            jobType: selectedJobType,
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

        let recommendations = MaterialsRecommender().recommendMaterials(for: context)
        suggestedMaterials = recommendations
        generated = recommendations.map(materialFromRecommendation)
        selectedMaterialName = recommendations.first?.name
    }

    private func materialFromRecommendation(_ rec: MaterialRecommendation) -> Material {
        MaterialResolutionHelper.material(
            from: rec,
            catalog: materialsStore,
            ownerID: Auth.auth().currentUser?.uid ?? "",
            fallbackUnitCost: settingsManager.commonMaterialPrice(for: rec.name)
        )
    }

    private func applySuggestion(from stats: MaterialUsageStats) {
        let recommendation = recommendation(from: stats)
        suggestedMaterials.append(recommendation)
        generated = makeEstimateMaterials(from: suggestedMaterials)
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
            estimatedUnitCost: stats.averageUnitCost.map { safeNumber($0) }
        )
    }

    private func makeEstimateMaterials(from recs: [MaterialRecommendation]) -> [Material] {
        recs.map(materialFromRecommendation)
    }

    private func createNewEstimateFromSuggestedMaterials() {
        let materials = makeEstimateMaterials(from: suggestedMaterials)
        _ = jobVM.createEstimate(from: materials, jobType: selectedJobType)
        dismiss()
    }

    private func addSuggestedMaterials(to job: Job) {
        let materials = makeEstimateMaterials(from: suggestedMaterials)
        jobVM.appendMaterials(materials, to: job.id)
    }
}
