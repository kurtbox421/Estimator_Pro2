import SwiftUI

struct DeleteAccountModalView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = DeleteAccountViewModel()

    @State private var showConfirmation = false
    @State private var showStatusAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Delete Account")
                    .font(.title2.bold())

                Text("Deleting your account will permanently remove your data (clients, jobs, invoices, materials, settings). This cannot be undone.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundColor(.white)
                .font(.headline.weight(.semibold))
                .disabled(viewModel.isProcessing)

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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red)
                )
                .foregroundColor(.white)
                .disabled(viewModel.isProcessing)
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 0.14, green: 0.16, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 12)
        .alert("Are you sure?", isPresented: $showConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove your account and all associated data.")
        }
        .alert(alertTitle, isPresented: $showStatusAlert) {
            Button("OK") {
                viewModel.statusMessage = nil
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.statusMessage ?? viewModel.errorMessage ?? "")
        }
        .alert("Reauthentication required", isPresented: $viewModel.showReauthenticationAlert) {
            Button("Sign in again") {
                isPresented = false
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
            isPresented = false
            session.signOut()
            return
        }

        if viewModel.statusMessage != nil || viewModel.errorMessage != nil {
            showStatusAlert = true
        }
    }

    private var alertTitle: String {
        viewModel.errorMessage == nil ? "Account deletion" : "Account deletion failed"
    }
}

#Preview {
    NavigationStack {
        DeleteAccountModalView(isPresented: .constant(true))
            .environmentObject(SessionViewModel())
    }
}
