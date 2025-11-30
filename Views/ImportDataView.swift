import SwiftUI
import UniformTypeIdentifiers

struct ImportDataView: View {
    @EnvironmentObject private var clientVM: ClientViewModel

    @State private var isImporting = false
    @State private var importMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import from other apps")
                .font(.title2.bold())

            Text("Export your clients from tools like Jobber or Joist as a CSV file, then import them here. We’ll create matching clients in Estimator Pro.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Expected CSV headers:")
                    .font(.subheadline.weight(.semibold))
                Text("Client Name, Company, Email, Phone, Address, City, State, Zip, Notes")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button {
                isImporting = true
            } label: {
                Label("Import clients from CSV", systemImage: "square.and.arrow.down.on.square")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            if let importMessage {
                Text(importMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    importMessage = "Could not read CSV as UTF-8 text."
                    return
                }

                let imported = parseClientsCSV(text: text)
                if imported.isEmpty {
                    importMessage = "No valid clients found in the file."
                } else {
                    for importedClient in imported {
                        clientVM.addImportedClient(importedClient)
                    }
                    importMessage = "Imported \(imported.count) clients."
                }
            } catch {
                importMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct ImportedClient {
    var name: String
    var company: String?
    var email: String?
    var phone: String?
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var notes: String?
}

/// Parse a clients CSV.
/// Expected columns (case-insensitive, order can vary):
/// "Client Name", "Company", "Email", "Phone", "Address", "City", "State", "Zip", "Notes"
/// Extra columns are ignored.
private func parseClientsCSV(text: String) -> [ImportedClient] {
    var results: [ImportedClient] = []

    let lines = text
        .components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

    guard let headerLine = lines.first else { return [] }

    let headers = headerLine
        .split(separator: ",", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    func index(for key: String) -> Int? {
        headers.firstIndex { $0.contains(key) }
    }

    let nameIndex     = index(for: "name")
    let companyIndex  = index(for: "company")
    let emailIndex    = index(for: "email")
    let phoneIndex    = index(for: "phone")
    let addressIndex  = index(for: "address")
    let cityIndex     = index(for: "city")
    let stateIndex    = index(for: "state")
    let zipIndex      = index(for: "zip")
    let notesIndex    = index(for: "note")

    guard let nameIndex else { return [] }

    for line in lines.dropFirst() {
        let columns = line
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        func value(at idx: Int?) -> String? {
            guard let idx, idx < columns.count else { return nil }
            let v = columns[idx]
            return v.isEmpty ? nil : v
        }

        let name = value(at: nameIndex) ?? ""
        if name.isEmpty { continue }

        let client = ImportedClient(
            name: name,
            company: value(at: companyIndex),
            email: value(at: emailIndex),
            phone: value(at: phoneIndex),
            address: value(at: addressIndex),
            city: value(at: cityIndex),
            state: value(at: stateIndex),
            zip: value(at: zipIndex),
            notes: value(at: notesIndex)
        )

        results.append(client)
    }

    return results
}

extension ClientViewModel {
    func addImportedClient(_ imported: ImportedClient) {
        let formattedAddress = formatAddress(from: imported)

        _ = addClient(
            name: imported.name,
            company: imported.company ?? "",
            address: formattedAddress,
            phone: imported.phone ?? "",
            email: imported.email ?? "",
            notes: imported.notes ?? ""
        )
    }

    private func formatAddress(from imported: ImportedClient) -> String {
        var segments: [String] = []

        if let line1 = imported.address, !line1.isEmpty {
            segments.append(line1)
        }

        var cityLineComponents: [String] = []
        if let city = imported.city, !city.isEmpty {
            cityLineComponents.append(city)
        }

        var stateZip = ""
        if let state = imported.state, !state.isEmpty {
            stateZip += state
        }
        if let zip = imported.zip, !zip.isEmpty {
            stateZip += stateZip.isEmpty ? zip : " \(zip)"
        }

        if !stateZip.isEmpty {
            cityLineComponents.append(stateZip)
        }

        if !cityLineComponents.isEmpty {
            segments.append(cityLineComponents.joined(separator: ", "))
        }

        return segments.joined(separator: " · ")
    }
}
