import SwiftUI

/// Onboarding flow — six steps, then straight into the app. Skippable at
/// any point. No paywall, and no rating *request*; both come later, once
/// the user has actually written something (see OnboardingViewModel).
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                skipButton

                stepContent
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
                    .animation(Theme.Animation.standard, value: viewModel.currentStep)

                bottomSection
            }
        }
        .onAppear {
            viewModel.onComplete = { onComplete?() }
        }
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .epigraph:
            OnboardingEpigraphView()
        case .whatThisIs:
            OnboardingWhatThisIsView()
        case .ritual:
            OnboardingRitualView()
        case .commitment:
            OnboardingCommitmentView(selectedDaysPerWeek: $viewModel.selectedDaysPerWeek)
        case .projection:
            OnboardingProjectionView(projection: viewModel.projection)
        case .ratingPrompt:
            OnboardingRatingPromptView()
        }
    }

    // MARK: - Skip Button
    private var skipButton: some View {
        HStack {
            Spacer()

            Button {
                viewModel.skip()
            } label: {
                Text(AppStrings.Onboarding.skipButton)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.trailing, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
        }
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            pageIndicator

            Button {
                viewModel.continueAction()
            } label: {
                Text(AppStrings.Onboarding.continueButton)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.bottom, Theme.Spacing.xxl)
    }

    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.self) { step in
                Circle()
                    .fill(
                        step == viewModel.currentStep
                            ? Theme.Colors.accent
                            : Theme.Colors.secondaryText.opacity(0.3)
                    )
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == viewModel.currentStep ? 1.2 : 1.0)
                    .animation(Theme.Animation.quick, value: viewModel.currentStep)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .environmentObject(PurchaseService.shared)
}
