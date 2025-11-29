import SwiftUI

struct MaterialGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var jobVM: JobViewModel
    let job: Job?

    @State private var descriptionText = ""
    @State private var suggestedMaterials: [GeneratedMaterial] = []
    @State private var isGenerating = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe the job")
                        .font(.headline)
                    Text("Provide a quick summary so we can suggest materials.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextEditor(text: $descriptionText)
                        .padding(12)
                        .frame(minHeight: 160)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                }

                Button {
                    isGenerating = true
                    generateMaterials()
                    isGenerating = false
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(isGenerating ? "Generating..." : "Generate materials")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.17, blue: 0.60),
                                Color(red: 0.90, green: 0.30, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)

                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 4)
                }

                if !suggestedMaterials.isEmpty {
                    List {
                        Section(header: Text("Suggested materials")) {
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
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Material generator")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyToJob()
                        dismiss()
                    }
                    .disabled(suggestedMaterials.isEmpty || job == nil)
                }
            }
        }
    }

    private func generateMaterials() {
        suggestedMaterials = MaterialSuggestionEngine.suggestMaterials(from: descriptionText)
    }

    private func applyToJob() {
        jobVM.applyGeneratedMaterials(suggestedMaterials, to: job)
    }
}
