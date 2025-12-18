import SwiftUI

struct PrivacyAndSecurityView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                RoundedCard {
                    VStack(spacing: 0) {
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            SettingsRow(
                                icon: "doc.plaintext",
                                title: "Privacy Policy",
                                tint: .white
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().overlay(Color.white.opacity(0.12))

                        NavigationLink {
                            DeleteAccountView()
                        } label: {
                            SettingsRow(
                                icon: "trash",
                                title: "Delete Account",
                                tint: .red,
                                titleColor: .red
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.49, green: 0.38, blue: 1.0),
                    Color(red: 0.25, green: 0.28, blue: 0.60)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Privacy & security")
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var tint: Color = .white
    var titleColor: Color = .white

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleColor)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 56)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        PrivacyAndSecurityView()
    }
}
