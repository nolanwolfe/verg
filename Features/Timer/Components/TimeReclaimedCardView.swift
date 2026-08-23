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
            Theme.Colors.scrim.opacity(0.94)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.Colors.flameOuter.opacity(0.28), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)

            // Deliberately tight. The old layout spaced everything at 24pt
            // with an hourglass on top, so the number floated in the middle
            // of a loose column. Grouped and closed up, the figure carries
            // the screen and the rest reads as caption to it.
            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(moment.eyebrow.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2.4)
                        .foregroundColor(Theme.Colors.accent)

                    if moment.minutes > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(moment.minutes)")
                                // Heavier and tighter than before, and no
                                // longer `.rounded` — rounded read friendly,
                                // and this screen is the one that should feel
                                // earned.
                                .font(.system(size: 104, weight: .bold))
                                .tracking(-4)
                                .monospacedDigit()
                                .foregroundColor(Theme.Colors.primaryText)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)

                            Text(moment.unit)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Theme.Colors.secondaryText)
                        }

                        Text(moment.framing)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    } else {
                        Text(moment.accessibleSentence)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.top, Theme.Spacing.xxs)
                    }
                }

                if moment.todayLine != nil || moment.daysLitLine != nil {
                    VStack(spacing: Theme.Spacing.xs) {
                        // A hairline of gold instead of a divider: the app's
                        // own rule, and the only ornament on the screen.
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.accent.opacity(0),
                                        Theme.Colors.accent.opacity(0.55),
                                        Theme.Colors.accent.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 96, height: 1)

                        if let todayLine = moment.todayLine {
                            Text(todayLine)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }

                        if let daysLitLine = moment.daysLitLine {
                            Text(daysLitLine)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                    }
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.Spacing.xl)
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
        moment: TimeReclaimed.moment(sessionSeconds: 24 * 60, todaySeconds: 41 * 60, daysLit: 4),
        onContinue: {}
    )
}
