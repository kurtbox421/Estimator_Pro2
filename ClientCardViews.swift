import SwiftUI

struct ClientEditableCard: View {
    @Binding var client: Client
    let jobCount: Int

    var body: some View {
        let summary = Client.jobSummary(for: jobCount)

        VStack(alignment: .leading, spacing: 14) {
            header(summary: summary)

            Divider().overlay(Color.white.opacity(0.15))

            ClientInfoTile(
                title: "Address",
                prompt: "123 Main St · City, ST",
                systemImage: "mappin.and.ellipse",
                text: $client.address,
                capitalization: .sentences
            )

            HStack(spacing: 12) {
                ClientInfoTile(
                    title: "Phone",
                    prompt: "(555) 123-4567",
                    systemImage: "phone.fill",
                    text: $client.phone,
                    capitalization: .never,
                    keyboardType: .phonePad
                )

                ClientInfoTile(
                    title: "Email",
                    prompt: "hello@example.com",
                    systemImage: "envelope.fill",
                    text: $client.email,
                    capitalization: .never,
                    keyboardType: .emailAddress
                )
            }

            ClientInfoTile(
                title: "Notes",
                prompt: "Reminders, preferences, etc.",
                systemImage: "note.text",
                text: $client.notes,
                capitalization: .sentences,
                disableAutocorrection: false
            )

            ClientJobTile(jobCount: jobCount, summary: summary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct ClientAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            Text(initials)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(width: 54, height: 54)
    }
}

struct ClientInfoTile: View {
    let title: String
    let prompt: String
    let systemImage: String?
    @Binding var text: String
    var capitalization: TextInputAutocapitalization = .words
    var keyboardType: UIKeyboardType = .default
    var disableAutocorrection: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let systemImage {
                Label(title.uppercased(), systemImage: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .labelStyle(.titleAndIcon)
            } else {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            TextField(prompt, text: $text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .keyboardType(keyboardType)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct ClientJobTile: View {
    let jobCount: Int
    let summary: String

    var body: some View {
        HStack {
            Label("Projects", systemImage: "briefcase.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            Spacer()

            Text(summary)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

extension ClientEditableCard {
    func header(summary: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ClientAvatar(initials: client.initials)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Client name", text: $client.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                TextField("Company", text: $client.company)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                Text(summary)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
