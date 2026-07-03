import SwiftUI

/// Full-screen celebration shown when a page milestone is crossed
struct MilestoneCelebrationView: View {
    let milestone: Milestone
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                StreakFlameIcon(size: 48)
                    .shadow(color: Color(hex: "FF9500").opacity(0.6), radius: 24)

                Image(systemName: milestone.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFCC00"), Color(hex: "FF9500")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: Theme.Spacing.xs) {
                    Text(milestone.title)
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text("Your journal is growing.")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
            }
            .padding(Theme.Spacing.lg)
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                appeared = true
            }
            AudioService.shared.playHaptic(.success)
        }
        .transition(.opacity)
    }
}

// MARK: - Preview
#Preview {
    MilestoneCelebrationView(
        milestone: Milestone.all[3],
        onContinue: {}
    )
}
