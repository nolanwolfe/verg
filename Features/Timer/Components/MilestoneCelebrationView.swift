import SwiftUI

/// Full-screen celebration shown when a milestone is crossed — page-count
/// milestones and weekly-goal milestones both render through this same view.
struct MilestoneCelebrationView: View {
    let icon: String
    let title: String
    var subtitle: String = "Your journal is growing."
    let onContinue: () -> Void

    @State private var appeared = false

    init(milestone: Milestone, onContinue: @escaping () -> Void) {
        self.icon = milestone.icon
        self.title = milestone.title
        self.onContinue = onContinue
    }

    init(goalMilestone: WeeklyGoalMilestone, onContinue: @escaping () -> Void) {
        self.icon = goalMilestone.icon
        self.title = goalMilestone.title
        self.subtitle = "You're building a habit."
        self.onContinue = onContinue
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                CandleFlameIcon(size: 48)
                    .shadow(color: Theme.Colors.flameOuter.opacity(0.6), radius: 24)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.flameInner, Theme.Colors.flameOuter],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(subtitle)
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
