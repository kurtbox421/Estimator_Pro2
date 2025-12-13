import SwiftUI

struct OnboardingChecklistCard: View {
    @EnvironmentObject private var onboarding: OnboardingProgressStore

    let goToCompanySettings: () -> Void
    let goToAddClient: () -> Void
    let goToCreateEstimate: () -> Void
    let goToPreviewPDF: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            progress
            steps
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        )
        .overlay(alignment: .topTrailing) { dismissButton }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Getting Started")
                .font(.title2.bold())
                .foregroundColor(.black)

            Text("Finish setup so you can send your first estimate in minutes.")
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: onboarding.progressFraction)
                .accentColor(.blue)
            Text("\(onboarding.completedCount) of \(onboarding.totalCount) completed")
                .font(.caption.bold())
                .foregroundColor(.black.opacity(0.65))
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            checklistRow(
                title: "Set up company profile",
                isComplete: onboarding.companyProfileComplete,
                action: goToCompanySettings
            )

            checklistRow(
                title: "Add a client",
                isComplete: onboarding.hasAtLeastOneClient,
                action: goToAddClient
            )

            checklistRow(
                title: "Create an estimate",
                isComplete: onboarding.hasAtLeastOneEstimate,
                action: goToCreateEstimate
            )

            checklistRow(
                title: "Preview a PDF",
                isComplete: onboarding.hasPreviewedPDF,
                action: goToPreviewPDF
            )
        }
    }

    private func checklistRow(title: String, isComplete: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
            }

            Spacer()

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Go", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var dismissButton: some View {
        Button {
            onboarding.markDismissed()
        } label: {
            Image(systemName: "xmark")
                .font(.caption.bold())
                .foregroundColor(.black.opacity(0.7))
                .padding(8)
                .background(Color.black.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingChecklistCard(
        goToCompanySettings: {},
        goToAddClient: {},
        goToCreateEstimate: {},
        goToPreviewPDF: {}
    )
    .environmentObject(OnboardingProgressStore())
    .padding()
    .background(Color.gray.opacity(0.1))
}
