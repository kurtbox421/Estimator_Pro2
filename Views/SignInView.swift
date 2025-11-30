import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: SessionViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button("Sign in") {
                AuthManager.shared.signIn(email: email, password: password) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            errorMessage = nil
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SignInView()
        .environmentObject(SessionViewModel())
}
