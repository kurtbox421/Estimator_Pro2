import SwiftUI

struct EmailTemplateSettingsView: View {
    @EnvironmentObject private var emailTemplateSettings: EmailTemplateSettingsStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $emailTemplateSettings.defaultEmailMessage)
                        .frame(minHeight: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2))
                        )

                    HStack {
                        Spacer()
                        Text("\(emailTemplateSettings.defaultEmailMessage.count) characters")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("Email message")
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
        .navigationTitle("Email Message")
    }
}
