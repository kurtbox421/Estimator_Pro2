import SwiftUI

struct AuthContainerView: View {
    @State private var mode: AuthMode = .signIn

    enum AuthMode {
        case signIn, signUp
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Text("Estimator Pro")
                    .font(.system(size: 34, weight: .bold))

                Picker("", selection: $mode) {
                    Text("Sign in").tag(AuthMode.signIn)
                    Text("Create account").tag(AuthMode.signUp)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch mode {
                    case .signIn:
                        SignInView()
                    case .signUp:
                        SignUpView()
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    AuthContainerView()
        .environmentObject(SessionViewModel())
}
