import SwiftUI

struct MaterialGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var jobVM: JobViewModel

    /// If opened from a specific job, it will be preselected.
    let preselectedJob: Job?

    @State private var descriptionText = ""
    @State private var suggestedMaterials: [GeneratedMaterial] = []
    @State private var isGenerating = false

    @State private var selectedJobID: Job.ID?

    // MARK: - Init

    init(job: Job? = nil) {
        self.preselectedJob = job
        _selectedJobID = State(initialValue: job?.id)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Describe the job")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $descriptionText)
                    .padding(8)
                    .frame(minHeight: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )

                Button(action: generateMaterials) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Label("Generate materials", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)

                if !suggestedMaterials.isEmpty {
                    targetJobPicker

                    Button(action: createNewJobFromGeneratedMaterials) {
                        Label("Create new job with these details", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)

                    List {
                        Section("Suggested materials") {
                            ForEach(suggestedMaterials) { material in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(material.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(material.details)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(material.estimatedTotal.formatted(.currency(code: "USD")))
                                        .font(.subheadline.bold())
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Material generator")
                            .font(.headline)
                        Text("(beta)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyToSelectedJob()
                        dismiss()
                    }
                    .disabled(!canApply)
                }
            }
        }
    }

    // MARK: - Target selection

    private var targetJobPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apply to estimate")
                .font(.headline)

            Picker("Estimate", selection: $selectedJobID) {
                Text("Select estimate").tag(Optional<Job.ID>.none)
                ForEach(jobVM.jobs) { job in
                    Text(job.name).tag(Optional(job.id))
                }
            }
        }
    }

    private var canApply: Bool {
        !suggestedMaterials.isEmpty && selectedJobID != nil
    }

    // MARK: - Actions

    private func generateMaterials() {
        isGenerating = true
        suggestedMaterials = MaterialSuggestionEngine.suggestMaterials(from: descriptionText)
        isGenerating = false

        // If no job selected yet but we have a preselected job, keep it.
        if selectedJobID == nil {
            selectedJobID = preselectedJob?.id
        }
    }

    private func applyToSelectedJob() {
        guard
            let id = selectedJobID,
            let targetJob = jobVM.jobs.first(where: { $0.id == id })
        else { return }

        jobVM.applyGeneratedMaterials(suggestedMaterials, to: targetJob)
    }

    private func createNewJobFromGeneratedMaterials() {
        guard !suggestedMaterials.isEmpty else { return }

        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let jobName = trimmedDescription.isEmpty ? "New Job" : trimmedDescription

        let newJob = Job(
            name: jobName,
            category: "",
            laborHours: 0,
            laborRate: 0,
            materials: materialsFromGenerated()
        )

        jobVM.add(newJob)
        selectedJobID = newJob.id
        dismiss()
    }

    private func materialsFromGenerated() -> [Material] {
        suggestedMaterials.map { gm in
            Material(
                id: UUID(),
                name: gm.name,
                quantity: gm.quantity,
                unitCost: gm.unitCost
            )
        }
    }
}
