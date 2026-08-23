import SwiftUI

// MARK: - Step 0: Epigraph
/// The only screen in the app that uses a serif face — everything else
/// stays SF Pro. No links, no footnote, no explanation of who Dante is.
/// This epigraph never reappears anywhere else in the app.
struct OnboardingEpigraphView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Text("Thou art alone the one from whom I took\nthe beautiful style that has done me honour.")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(10)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Dante, to Virgil, in the dark wood.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
                .frame(height: Theme.Spacing.xxl)

            Text("Verg is named for him — the guide who walks with you, and then leaves once you reach the summit of the mountain.")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, Theme.Spacing.xl)

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

            CandleView(progress: 1.0, isBurning: true)
                .frame(height: 260)
                .shadow(color: Theme.Colors.flameOuter.opacity(0.4), radius: 30)

            Text(AppStrings.Onboarding.whatThisIsLine)
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
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

// MARK: - Step 5: Rating Prompt
struct OnboardingRatingPromptView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.accent)

            VStack(spacing: Theme.Spacing.sm) {
                Text(AppStrings.Onboarding.ratingPromptTitle)
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.primaryText)

                Text(AppStrings.Onboarding.ratingPromptBody)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

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

#Preview("Rating Prompt") {
    ZStack { Theme.Colors.background.ignoresSafeArea(); OnboardingRatingPromptView() }
}
