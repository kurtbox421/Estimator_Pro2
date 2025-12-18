import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = DeleteAccountViewModel()

    @State private var showConfirmation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Delete Account")
                .font(.title.bold())

            Text("Deleting your account will permanently remove your data, including clients, jobs, invoices, materials, and settings. This action cannot be undone.")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                HStack {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(viewModel.isProcessing ? "Deleting..." : "Delete Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isProcessing)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Delete Account")
        .alert("Are you sure?", isPresented: $showConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove your account and all associated data.")
        }
        .alert(alertTitle, isPresented: Binding(get: {
            viewModel.statusMessage != nil || viewModel.errorMessage != nil
        }, set: { newValue in
            if !newValue {
                viewModel.statusMessage = nil
                viewModel.errorMessage = nil
            }
        })) {
            Button(viewModel.deletionCompleted ? "Return to login" : "OK") {
                if viewModel.deletionCompleted {
                    session.signOut()
                }
            }
        } message: {
            Text(viewModel.statusMessage ?? viewModel.errorMessage ?? "")
        }
        .alert("Reauthentication required", isPresented: $viewModel.showReauthenticationAlert) {
            Button("Sign in again") {
                session.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please sign back in to complete account deletion.")
        }
    }

    private func performDeletion() async {
        await viewModel.deleteAccount()
        if viewModel.deletionCompleted {
            session.signOut()
        }
    }

    private var alertTitle: String {
        viewModel.deletionCompleted ? "Account deleted" : "Account deletion"
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(SessionViewModel())
    }
}
