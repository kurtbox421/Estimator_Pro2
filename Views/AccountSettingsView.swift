import SwiftUI

struct AccountSettingsView: View {
    @State private var showingDeleteAccount = false
    @State private var showingPrivacyPolicy = false

    private let privacyPolicyURL = URL(string: "https://www.apple.com/legal/privacy/en-ww/")!

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoundedCard {
                        VStack(spacing: 0) {
                            Button {
                                showingPrivacyPolicy = true
                            } label: {
                                SettingsRow(
                                    icon: "doc.plaintext",
                                    title: "Privacy Policy",
                                    tint: .white
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(Color.white.opacity(0.12))

                            Button {
                                showingDeleteAccount = true
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showingDeleteAccount {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingDeleteAccount = false
                    }

                DeleteAccountModalView(isPresented: $showingDeleteAccount)
                    .frame(maxWidth: 520)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
            }
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
        .animation(
            .spring(response: 0.35, dampingFraction: 0.82, blendDuration: 0.2),
            value: showingDeleteAccount
        )
        .sheet(isPresented: $showingPrivacyPolicy) {
            SafariView(url: privacyPolicyURL)
                .ignoresSafeArea()
        }
        .navigationTitle("Account Settings")
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
        AccountSettingsView()
    }
}
