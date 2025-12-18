import SwiftUI

struct PrivacyAndSecurityView: View {
    var body: some View {
        List {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "doc.plaintext")
            }

            NavigationLink {
                DeleteAccountView()
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy & security")
    }
}

#Preview {
    NavigationStack {
        PrivacyAndSecurityView()
    }
}
