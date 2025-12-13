import SwiftUI

struct JobDocumentLayout<Summary: View, Document: View>: View {
    let summary: Summary
    let document: Document
    let customer: AnyView
    let quickActions: AnyView
    let materials: AnyView

    init(
        summary: Summary,
        document: Document,
        @ViewBuilder customer: () -> some View,
        @ViewBuilder quickActions: () -> some View,
        @ViewBuilder materials: () -> some View
    ) {
        self.summary = summary
        self.document = document
        self.customer = AnyView(customer())
        self.quickActions = AnyView(quickActions())
        self.materials = AnyView(materials())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summary
                document
                customer
                quickActions
                materials
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
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
    }
}

// MARK: - Shared styling

struct RoundedCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            content()
                .padding(20)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PrimaryBlueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.blue.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
    }
}

struct GreenActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
    }
}

struct SecondaryPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.14))
            )
            .foregroundColor(.white)
    }
}
