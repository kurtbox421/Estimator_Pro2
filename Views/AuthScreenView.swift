import SwiftUI

struct AuthScreenView: View {
    enum Mode {
        case signIn
        case signUp
    }

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var onboarding: OnboardingProgressStore

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.49, green: 0.38, blue: 1.0),
            Color(red: 0.29, green: 0.20, blue: 0.70)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var primaryColor: Color {
        Color(red: 0.49, green: 0.38, blue: 1.0)
    }

    var body: some View {
        ZStack {
            primaryGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        logoMark
                            .accessibilityHidden(true)

                        Text("Estimator Pro")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Fast, smart job estimating\nfor contractors")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 420)
                    .padding(.top, 24)

                    VStack(spacing: 20) {
                        HStack(spacing: 0) {
                            modeButton(title: "Sign in", mode: .signIn)
                            modeButton(title: "Create account", mode: .signUp)
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(Color(.secondarySystemBackground))
                        )

                        Group {
                            if mode == .signUp {
                                TextField("Name", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .roundedAuthField()
                            }

                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .roundedAuthField()

                            SecureField("Password", text: $password)
                                .roundedAuthField()

                            if mode == .signUp {
                                SecureField("Confirm password", text: $confirmPassword)
                                    .roundedAuthField()
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: handlePrimaryAction) {
                            HStack {
                                if isBusy {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(mode == .signIn ? "Sign in" : "Create account")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(primaryColor)
                        .disabled(isPrimaryButtonDisabled)
                    }
                    .padding(24)
                    .frame(maxWidth: 520)
                    .background(Color(.systemBackground))
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var isPrimaryButtonDisabled: Bool {
        switch mode {
        case .signIn:
            return isBusy || email.isEmpty || password.isEmpty
        case .signUp:
            return isBusy || name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty
        }
    }

    private func handlePrimaryAction() {
        switch mode {
        case .signIn:
            signIn()
        case .signUp:
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
            signUp()
        }
    }

    private func signIn() {
        isBusy = true
        AuthManager.shared.signIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                isBusy = false
                switch result {
                case .success:
                    errorMessage = nil
                case .failure(let error):
                    let nsError = error as NSError
                    print("AUTH SIGN-IN ERROR:", error)
                    print("AUTH SIGN-IN NSERROR:", nsError)
                    print("AUTH SIGN-IN USERINFO:", nsError.userInfo)
                    errorMessage = nsError.localizedDescription
                }
            }
        }
    }

    private func signUp() {
        isBusy = true
        AuthManager.shared.signUp(
            email: email,
            password: password,
            displayName: name,
            onboarding: onboarding
        ) { result in
            DispatchQueue.main.async {
                isBusy = false
                switch result {
                case .success:
                    errorMessage = nil
                case .failure(let error):
                    let nsError = error as NSError
                    print("AUTH SIGN-UP ERROR:", error)
                    print("AUTH SIGN-UP NSERROR:", nsError)
                    print("AUTH SIGN-UP USERINFO:", nsError.userInfo)
                    errorMessage = nsError.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func modeButton(title: String, mode: Mode) -> some View {
        let isSelected = self.mode == mode
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.mode = mode
                errorMessage = nil
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(isSelected ? primaryColor : .secondary)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var logoMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)
                .frame(width: 82, height: 82)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(primaryColor, lineWidth: 3)
                )

            Image(systemName: "ruler")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .foregroundColor(primaryColor)
                .rotationEffect(.degrees(-45))
        }
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
    }
}

struct AuthFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

extension View {
    func roundedAuthField() -> some View {
        modifier(AuthFieldModifier())
    }
}

#Preview {
    let session = SessionManager()
    return AuthScreenView()
        .environmentObject(session)
        .environmentObject(OnboardingProgressStore(session: session))
}
