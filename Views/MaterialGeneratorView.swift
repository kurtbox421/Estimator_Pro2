import SwiftUI

struct MaterialGeneratorView: View {
    @State private var selectedJobType: MaterialJobType = .interiorWallBuild
    @State private var lengthText: String = ""
    @State private var secondaryText: String = ""
    @State private var generated: [Material] = []
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section("Job Type") {
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
                            if let notes = item.notes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Material Generator")
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
        let length = Double(lengthText)
        let secondary = Double(secondaryText)

        guard length != nil || secondary != nil else {
            validationMessage = "Enter at least one dimension."
            generated = []
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
        generated = recommendations.map { rec in
            Material(
                name: rec.name,
                quantity: rec.quantity,
                unitCost: 0,
                productURL: nil,
                unit: rec.unit,
                notes: rec.notes
            )
        }
    }
}
