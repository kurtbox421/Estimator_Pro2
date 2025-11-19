import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color(red: 0.49, green: 0.38, blue: 1.0)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                logoMark
                    .frame(width: 144, height: 144)

                VStack(spacing: 8) {
                    Text("Estimator\nPro")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Text("Fast, Smart Job Estimating\nfor Contractors")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
            .padding(32)
        }
    }

    private var logoMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.85))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.49, green: 0.38, blue: 1.0), lineWidth: 12)
                .padding(20)

            Image(systemName: "ruler")
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(-45))
                .foregroundStyle(Color(red: 0.49, green: 0.38, blue: 1.0))
                .padding(36)
        }
    }
}

#Preview {
    SplashScreenView()
}
