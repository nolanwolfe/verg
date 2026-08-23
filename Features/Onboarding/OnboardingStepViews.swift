import SwiftUI

// MARK: - Step 0: Epigraph
/// The only screen in the app that uses a serif face — everything else
/// stays SF Pro. No links, no footnote, no explanation of who Dante is.
/// This epigraph never reappears anywhere else in the app.
struct OnboardingEpigraphView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                // Three lines of verse, and they have to stay three lines —
                // lineLimit pins the count so a line too wide for the screen
                // scales down instead of wrapping and breaking the metre.
                Text(AppStrings.Onboarding.epigraphQuote)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(9)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)

                Text(AppStrings.Onboarding.epigraphAttribution)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Step 1: What This Is
/// The real candle component, not a generic icon — this is the one visual
/// promise the whole app is built around.
struct OnboardingWhatThisIsView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // The candle is the hero here — this doubles as the first look
            // at the home screen, so it's sized close to how it appears
            // there rather than as a small illustration.
            //
            // CandleView lays out 160x425 from fixed internal sizes (160
            // glow + 50 flame + 15 wick + 200 wax), and scaleEffect shrinks
            // the drawing but not the layout box. The glow is additionally
            // drawn with `.offset(y: 60)` inside its own slot, so the top
            // 60pt of that box is empty. Frame = (425 - 60) x scale, and
            // offset = -(60 x scale)/2, which makes the ink fill the
            // reserved space exactly instead of sitting low inside it.
            CandleView(progress: 1.0, isBurning: true)
                .scaleEffect(0.9)
                .frame(width: 144, height: 328)
                .offset(y: -27)
                .shadow(color: Theme.Colors.flameOuter.opacity(0.4), radius: 30)

            VStack(spacing: Theme.Spacing.xxs) {
                Text(AppStrings.Onboarding.pitchHeadline)
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text(AppStrings.Onboarding.pitchSubline)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Step 2: The Ritual
struct OnboardingRitualView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text(AppStrings.Onboarding.ritualTitle)
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Array(AppStrings.Onboarding.ritualSteps.enumerated()), id: \.offset) { _, step in
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.cardBackground)
                                .frame(width: 44, height: 44)
                            Image(systemName: step.icon)
                                .foregroundColor(Theme.Colors.accent)
                                .font(.system(size: 18, weight: .medium))
                        }

                        Text(step.text)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Step 3: Commitment
struct OnboardingCommitmentView: View {
    @Binding var selectedDaysPerWeek: Int

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Text(AppStrings.Onboarding.commitmentTitle)
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text(AppStrings.Onboarding.commitmentSubtitle)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(AppStrings.Onboarding.commitmentOptions, id: \.self) { days in
                    Button {
                        selectedDaysPerWeek = days
                    } label: {
                        HStack {
                            Text("\(days) days a week")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)

                            Spacer()

                            if selectedDaysPerWeek == days {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.accent)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous)
                                .stroke(
                                    selectedDaysPerWeek == days ? Theme.Colors.accent : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Step 4: Projection
struct OnboardingProjectionView: View {
    let projection: OnboardingProjection.Result

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            Text(AppStrings.Onboarding.projectionIntro)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)

            VStack(spacing: Theme.Spacing.xl) {
                statBlock(value: "\(projection.pages)", unit: projection.pages == 1 ? "page" : "pages")
                statBlock(
                    value: "\(Int(projection.hours.rounded()))",
                    unit: "hours off your phone"
                )
            }

            Text(projection.closingLine)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }

    private func statBlock(value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primaryText)
                .monospacedDigit()

            Text(unit)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }
}

// MARK: - Step 5: Closing Note
/// The last screen before the app. Mentions the rating without asking for
/// one — the system prompt fires on the third saved page, when there's
/// something to actually judge. The mark is five gold stars, the same ones
/// an earned achievement carries.
struct OnboardingRatingPromptView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            // The same gold star as an earned achievement, five across and
            // staggered so the row glimmers rather than blinking as one.
            HStack(spacing: Theme.Spacing.xxs) {
                ForEach(0..<5, id: \.self) { index in
                    AchievementStarIcon(size: 26, phase: Double(index) * 0.12)
                }
            }
            .shadow(color: Color(hex: "D4A017").opacity(0.4), radius: 12)

            VStack(spacing: Theme.Spacing.xs) {
                // title, not largeTitle: at 34pt this wrapped to two lines
                // and pushed the screen past the bottom on an SE.
                Text(AppStrings.Onboarding.ratingPromptTitle)
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // One line, app name and candle together.
                Text(AppStrings.Onboarding.ratingPromptBody)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Previews
#Preview("What This Is") {
    ZStack { Theme.Colors.background.ignoresSafeArea(); OnboardingWhatThisIsView() }
}

#Preview("Ritual") {
    ZStack { Theme.Colors.background.ignoresSafeArea(); OnboardingRitualView() }
}

#Preview("Commitment") {
    ZStack { Theme.Colors.background.ignoresSafeArea(); OnboardingCommitmentView(selectedDaysPerWeek: .constant(5)) }
}

#Preview("Projection") {
    ZStack {
        Theme.Colors.background.ignoresSafeArea()
        OnboardingProjectionView(projection: OnboardingProjection.compute(daysPerWeek: 5))
    }
}

#Preview("Closing Note") {
    ZStack { Theme.Colors.background.ignoresSafeArea(); OnboardingRatingPromptView() }
}
