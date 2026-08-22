import Foundation
import Combine
import SwiftUI

/// ViewModel for the Onboarding flow — 5 steps (what this is, the ritual,
/// commitment, projection, rating prompt), then the paywall.
final class OnboardingViewModel: ObservableObject {

    enum Step: Int, CaseIterable {
        case whatThisIs
        case ritual
        case commitment
        case projection
        case ratingPrompt
    }

    // MARK: - Published Properties
    @Published var currentStep: Step = .whatThisIs
    @Published var selectedDaysPerWeek: Int = 5
    @Published var showPaywall: Bool = false

    // MARK: - Dependencies
    private let storageService: StorageService

    // MARK: - Callbacks
    var onComplete: (() -> Void)?

    // MARK: - Computed Properties
    var isLastStep: Bool {
        currentStep == Step.allCases.last
    }

    var projection: OnboardingProjection.Result {
        OnboardingProjection.compute(daysPerWeek: selectedDaysPerWeek)
    }

    // MARK: - Initialization
    init(storageService: StorageService = .shared) {
        self.storageService = storageService
    }

    // MARK: - Actions

    func selectDaysPerWeek(_ days: Int) {
        selectedDaysPerWeek = days
    }

    /// Advance to the next step, or — on the last step — persist the
    /// commitment, fire the rating prompt, and hand off to the paywall.
    func continueAction() {
        guard let currentIndex = Step.allCases.firstIndex(of: currentStep) else { return }

        if isLastStep {
            finishRitualSteps()
            return
        }

        let nextIndex = Step.allCases.index(after: currentIndex)
        withAnimation(Theme.Animation.standard) {
            currentStep = Step.allCases[nextIndex]
        }
    }

    /// Bypasses everything, including the paywall — writing is always free,
    /// and this app doesn't force monetization on someone who opted out of
    /// the pitch. Nothing from the flow (including any commitment already
    /// picked) is persisted.
    func skip() {
        completeOnboarding()
    }

    /// Called once the paywall closes, whether subscribed or dismissed —
    /// either way, onboarding is done.
    func paywallFinished() {
        showPaywall = false
        completeOnboarding()
    }

    // MARK: - Private Methods

    private func finishRitualSteps() {
        storageService.setWeeklyCommitmentDaysPerWeek(selectedDaysPerWeek)
        MainActor.assumeIsolated {
            RatingPromptService.requestReviewIfAppropriate()
        }
        showPaywall = true
    }

    private func completeOnboarding() {
        storageService.setHasSeenOnboarding(true)
        onComplete?()
    }
}
