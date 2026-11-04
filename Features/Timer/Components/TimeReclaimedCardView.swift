import SwiftUI

/// Full-screen "you wrote instead of scrolling" reveal, shown once per
/// session right after the page is saved. This is meant to be the nicest
/// screen in the app — the one moment designed to be screenshotted — so it
/// gets the same big-number treatment as a stat card, not a toast.
struct TimeReclaimedCardView: View {
    let moment: TimeReclaimedMoment
    let onContinue: () -> Void

    @State private var appeared = false
    /// The story-sized image the Share button hands to the share sheet,
    /// rendered once when the card appears.
    @State private var shareImage: Image?

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

                VStack(spacing: Theme.Spacing.sm) {
                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    // The share is the session, not the page: the
                    // handwriting never leaves the phone, only the minutes.
                    if let shareImage {
                        ShareLink(
                            item: shareImage,
                            preview: SharePreview("Ten minutes on paper", image: shareImage)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(TextLinkButtonStyle())
                        .accessibilityIdentifier("timeReclaimed.share")
                    }
                }
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
            if moment.minutes > 0 {
                shareImage = ShareStoryCard.render(moment)
            }
            AudioService.shared.playHaptic(.success)
        }
        .transition(.opacity)
    }
}

// MARK: - Share card

/// A 9:16 image of the session for Instagram and TikTok stories: the candle,
/// the minutes, days lit, and a small mark. Fixed colours rather than the
/// theme's adaptive ones, so it looks the same whatever the phone's
/// appearance, and everyone's card is recognisably the same object.
struct ShareStoryCard: View {
    let moment: TimeReclaimedMoment

    private let ink = Color(hex: "120B1D")
    private let gold = Color(hex: "E2BD5A")
    private let text = Color(hex: "F5EFE6")

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A1029"), ink], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Color(hex: "FFA84C").opacity(0.35), Color(hex: "9C46BE").opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 4,
                endRadius: 260
            )

            VStack(spacing: 0) {
                Spacer().frame(height: 120)

                // The candle: flame over a short wax body.
                VStack(spacing: 0) {
                    FlameShape()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FF7A1A"), Color(hex: "FFD25C"), .white],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 26, height: 40)
                        .shadow(color: Color(hex: "FFB347").opacity(0.9), radius: 18)
                    Rectangle().fill(Color(hex: "3A2630")).frame(width: 2, height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color(hex: "D9C4B8"), Color(hex: "FBF1E2"), Color(hex: "B89FAE")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: 36, height: 70)
                }

                Spacer().frame(height: 64)

                Text("\(moment.minutes)")
                    .font(.system(size: 120, weight: .bold, design: .serif))
                    .foregroundColor(text)
                Text("\(moment.unit) on paper")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(text.opacity(0.9))
                Text(moment.framing)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(gold)
                    .padding(.top, 2)

                if let daysLitLine = moment.daysLitLine {
                    Rectangle()
                        .fill(gold.opacity(0.55))
                        .frame(width: 72, height: 1)
                        .padding(.top, 28)
                    Text(daysLitLine)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(text)
                        .padding(.top, 14)
                }

                Spacer()

                // The mark: outbound text, so the candle emoji is allowed.
                Text("Verg 🕯️  journal on paper")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(gold)
                Text("verg.app")
                    .font(.system(size: 13))
                    .foregroundColor(text.opacity(0.6))
                    .padding(.top, 4)
                Spacer().frame(height: 72)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
        .frame(width: 360, height: 640)
    }

    /// 1080 x 1920, the story size, or nil if rendering fails.
    @MainActor
    static func render(_ moment: TimeReclaimedMoment) -> Image? {
        let renderer = ImageRenderer(content: ShareStoryCard(moment: moment))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Preview
#Preview {
    TimeReclaimedCardView(
        moment: TimeReclaimed.moment(sessionSeconds: 24 * 60, todaySeconds: 41 * 60, daysLit: 4),
        onContinue: {}
    )
}
