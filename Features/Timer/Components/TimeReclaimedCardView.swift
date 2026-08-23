import SwiftUI

/// Full-screen "you wrote instead of scrolling" reveal, shown once per
/// session right after the page is saved. This is meant to be the nicest
/// screen in the app — the one moment designed to be screenshotted — so it
/// gets the same big-number treatment as a stat card, not a toast.
struct TimeReclaimedCardView: View {
    let moment: TimeReclaimedMoment
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.Colors.flameOuter.opacity(0.28), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "hourglass")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.Colors.accent)
                    .shadow(color: Theme.Colors.accent.opacity(0.5), radius: 16)

                if moment.minutes > 0 {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(moment.leadingText.uppercased())
                            .font(Theme.Typography.caption.weight(.semibold))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.secondaryText)

                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                            Text("\(moment.minutes)")
                                .font(.system(size: 88, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.primaryText)
                                .monospacedDigit()

                            Text(moment.minutes == 1 ? "minute" : "minutes")
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }

                        Text(moment.trailingText)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text(moment.accessibleSentence)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                }

                if moment.daysLit > 1 {
                    HStack(spacing: Theme.Spacing.xxs) {
                        CandleFlameIcon(size: 16)
                        Text("\(moment.daysLit) days lit")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
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
            .scaleEffect(appeared ? 1.0 : 0.85)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(moment.accessibleSentence)
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
    TimeReclaimedCardView(
        moment: TimeReclaimed.moment(todaySeconds: 12 * 60, isFirstSessionToday: true, daysLit: 4),
        onContinue: {}
    )
}
