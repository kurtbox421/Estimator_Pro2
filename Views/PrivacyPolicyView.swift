import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(PrivacyPolicyContent.text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
