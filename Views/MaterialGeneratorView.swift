import SwiftUI

struct MaterialGeneratorView: View {
    @EnvironmentObject var materialsStore: MaterialsCatalogStore

    @State private var jobType: JobType = .interiorWall
    @State private var wallLength: String = "10"
    @State private var wallHeight: String = "8"
    @State private var roomArea: String = "120"
    @State private var roomPerimeter: String = "44"
    @State private var deckArea: String = "200"
    @State private var openingCount: String = "1"
    @State private var bathroomCount: String = "1"

    @State private var generated: [GeneratedMaterial] = []

    var body: some View {
        Form {
            Section("Job Type") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(JobType.allCases) { type in
                            Button {
                                jobType = type
                            } label: {
                                Text(type.displayName)
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        jobType == type
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                jobType == type
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

            parametersSection

            Button("Generate Materials") {
                let context = buildContext()
                let generator = JobMaterialGenerator(catalog: materialsStore)
                generated = generator.generateMaterials(for: jobType, context: context)
            }

            if !generated.isEmpty {
                Section("Suggested Materials") {
                    ForEach(generated, id: \.material.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.material.name)
                                .font(.headline)

                            // FIXED — correct string interpolation with escaped quotes
                            Text("\(item.quantity, specifier: \"%.2f\") \(item.material.unit)")

                            // FIXED — correct total formatting
                            Text("Total: $\(item.totalCost, specifier: \"%.2f\")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Material Generator")
    }

    @ViewBuilder
    private var parametersSection: some View {
        switch jobType {
        case .interiorWall:
            Section("Wall Dimensions (ft)") {
                TextField("Wall length", text: $wallLength)
                    .keyboardType(.decimalPad)
                TextField("Wall height", text: $wallHeight)
                    .keyboardType(.decimalPad)
            }

        case .lvpFloor, .paintRoom:
            Section("Room Data") {
                TextField("Floor area (sq ft)", text: $roomArea)
                    .keyboardType(.decimalPad)
                TextField("Perimeter (ft)", text: $roomPerimeter)
                    .keyboardType(.decimalPad)
                if jobType == .paintRoom {
                    TextField("Wall height (ft)", text: $wallHeight)
                        .keyboardType(.decimalPad)
                }
            }

        case .basicBathRemodel:
            Section("Bathroom") {
                TextField("Tile area (sq ft)", text: $roomArea)
                    .keyboardType(.decimalPad)
                TextField("Bathroom count", text: $bathroomCount)
                    .keyboardType(.numberPad)
            }

        case .deckSurfaceReplace:
            Section("Deck") {
                TextField("Deck area (sq ft)", text: $deckArea)
                    .keyboardType(.decimalPad)
                TextField("Deck length (ft)", text: $wallLength)
                    .keyboardType(.decimalPad)
            }

        case .windowInstall:
            Section("Openings") {
                TextField("Window/door count", text: $openingCount)
                    .keyboardType(.numberPad)
                TextField("Perimeter trim (ft)", text: $roomPerimeter)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private func buildContext() -> QuantityContext {
        func d(_ string: String) -> Double? {
            Double(string.replacingOccurrences(of: ",", with: "."))
        }
        func i(_ string: String) -> Int? {
            Int(string)
        }

        return QuantityContext(
            wallLengthFt: d(wallLength),
            wallHeightFt: d(wallHeight),
            roomFloorAreaSqFt: d(roomArea),
            roomPerimeterFt: d(roomPerimeter),
            deckAreaSqFt: d(deckArea),
            deckLengthFt: d(wallLength),
            deckJoistSpanFt: nil,
            concreteVolumeCuFt: nil,
            openingCount: i(openingCount),
            bathroomCount: i(bathroomCount),
            tileAreaSqFt: d(roomArea)
        )
    }
}
