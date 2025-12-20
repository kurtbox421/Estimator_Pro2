import FirebaseAuth
import StoreKit
import SwiftUI
import UIKit

struct AccountSettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var session: SessionViewModel

    @State private var showingDeleteAccount = false
    @State private var showingPrivacyPolicy = false
    @State private var showingSignOutConfirmation = false
    @State private var isRestoringPurchases = false
    @State private var restoreAlert: AlertDetails?

    private let privacyPolicyURL = URL(string: "https://www.apple.com/legal/privacy/en-ww/")!
    private let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    SettingsSection(title: "Account") {
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "envelope",
                                title: "Email",
                                value: currentEmail ?? "Unknown",
                                showsChevron: false,
                                isEnabled: currentEmail != nil
                            )
                            .accessibilityLabel("Email")

                            Divider().overlay(Color.white.opacity(0.12))

                            Button {
                                showingSignOutConfirmation = true
                            } label: {
                                SettingsRow(
                                    icon: "arrow.backward.circle",
                                    title: "Sign Out",
                                    showsChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Sign Out")
                        }
                    }

                    SettingsSection(title: "Subscriptions") {
                        VStack(spacing: 0) {
                            Button {
                                Task { await openManageSubscriptions() }
                            } label: {
                                SettingsRow(
                                    icon: "creditcard",
                                    title: "Manage Subscription",
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().overlay(Color.white.opacity(0.12))

                            Button {
                                Task { await restorePurchases() }
                            } label: {
                                SettingsRow(
                                    icon: "arrow.clockwise",
                                    title: "Restore Purchases",
                                    showsChevron: false,
                                    isLoading: isRestoringPurchases
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isRestoringPurchases)
                        }
                    }

                    SettingsSection(title: "Privacy") {
                        VStack(spacing: 0) {
                            Button {
                                showingPrivacyPolicy = true
                            } label: {
                                SettingsRow(
                                    icon: "doc.plaintext",
                                    title: "Privacy Policy",
                                    showsChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SettingsSection(title: "Danger Zone") {
                        VStack(spacing: 0) {
                            Button {
                                showingDeleteAccount = true
                            } label: {
                                SettingsRow(
                                    icon: "trash",
                                    title: "Delete Account",
                                    tint: .red,
                                    titleColor: .red,
                                    showsChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete Account")
                        }
                    }
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
        .alert("Sign out?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                session.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be returned to the login screen.")
        }
        .alert(restoreAlert?.title ?? "", isPresented: Binding(
            get: { restoreAlert != nil },
            set: { _ in restoreAlert = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreAlert?.message ?? "")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            SafariView(url: privacyPolicyURL)
                .ignoresSafeArea()
        }
        .navigationTitle("Account Settings")
    }

    private var currentEmail: String? {
        Auth.auth().currentUser?.email
    }

    private func openManageSubscriptions() async {
        if #available(iOS 15.0, *) {
            if let windowScene = activeWindowScene() {
                do {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                } catch {
                    openURL(subscriptionsURL)
                }
            } else {
                openURL(subscriptionsURL)
            }
        } else {
            openURL(subscriptionsURL)
        }
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return activeScene
        }
        return scenes.first
    }

    private func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true

        defer { isRestoringPurchases = false }

        if #available(iOS 15.0, *) {
            do {
                try await AppStore.sync()
                restoreAlert = AlertDetails(
                    title: "Restore Complete",
                    message: "Your purchases have been restored."
                )
            } catch {
                restoreAlert = AlertDetails(
                    title: "Restore Failed",
                    message: error.localizedDescription
                )
            }
        } else {
            restoreAlert = AlertDetails(
                title: "Restore Unavailable",
                message: "Purchase restoration requires a newer iOS version."
            )
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            RoundedCard {
                content()
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 24)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var tint: Color = .white
    var titleColor: Color = .white
    var showsChevron: Bool = false
    var isLoading: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleColor)

            Spacer()

            if let value {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            if isLoading {
                ProgressView()
                    .tint(.white.opacity(0.8))
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 56)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.6)
        .disabled(!isEnabled)
    }
}

private struct AlertDetails: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        AccountSettingsView()
            .environmentObject(SessionViewModel())
    }
}
