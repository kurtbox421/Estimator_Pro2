import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var session: SessionViewModel
    @EnvironmentObject private var onboarding: OnboardingProgressStore

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            SecureField("Confirm password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                guard password == confirmPassword else {
                    errorMessage = "Passwords do not match."
                    return
                }

                AuthManager.shared.signUp(
                    email: email,
                    password: password,
                    displayName: name,
                    onboarding: onboarding
                ) { result in
                    DispatchQueue.main.async {
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
            }) {
                Text("Create account")
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty || email.isEmpty || password.isEmpty)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SignUpView()
        .environmentObject(SessionViewModel())
}
