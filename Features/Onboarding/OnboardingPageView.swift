import SwiftUI

/// Reusable component for each onboarding page
struct OnboardingPageView: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Illustration area
            illustrationView

            Spacer()
                .frame(height: Theme.Spacing.lg)

            // Text content
            textContent

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Illustration
    private var illustrationView: some View {
        ZStack {
            // Glow effect behind icon
            Circle()
                .fill(Theme.Colors.accent.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 40)

            // Icon
            Image(systemName: imageName)
                .font(.system(size: 100, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "BF5AF2"), Color(hex: "FF375F")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(height: 220)
    }

    // MARK: - Text Content
    private var textContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        OnboardingPageView(
            imageName: "flame",
            title: "Write by candlelight",
            subtitle: "10 minutes. No screens. Just pen and paper."
        )
    }
}
