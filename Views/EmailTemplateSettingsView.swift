import SwiftUI

struct EmailTemplateSettingsView: View {
    @EnvironmentObject private var emailTemplateSettings: EmailTemplateSettingsStore

    private let placeholderTokens: [String] = [
        "{{clientName}}",
        "{{jobName}}",
        "{{documentType}} (Invoice/Estimate)",
        "{{invoiceNumber}}",
        "{{estimateNumber}}",
        "{{total}}",
        "{{companyName}}"
    ]

    var body: some View {
        List {
            Section("Subject") {
                TextField("Email subject", text: $emailTemplateSettings.defaultEmailSubject)
            }

            Section("Message body") {
                TextEditor(text: $emailTemplateSettings.defaultEmailBody)
                    .frame(minHeight: 180)
            }

            Section("Available placeholders") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(placeholderTokens, id: \.self) { token in
                        Text(token)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Button(role: .none) {
                    emailTemplateSettings.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to defaults")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Email Template")
    }
}
