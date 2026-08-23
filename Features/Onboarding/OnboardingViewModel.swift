import Foundation
import Combine
import SwiftUI

/// ViewModel for the Onboarding flow — epigraph, what this is, the ritual,
/// commitment, projection, closing note, and then straight into the app.
///
/// The closing note mentions the rating but does not request it, and the
/// paywall doesn't appear here at all. Both are earned rather than
/// front-loaded: the system rating prompt fires after the third saved page,
/// the paywall after the seventh. Someone who has written nothing yet has
/// no basis to rate the app and no reason to buy an archive they haven't
/// filled.
final class OnboardingViewModel: ObservableObject {

    enum Step: Int, CaseIterable {
        case epigraph
        case whatThisIs
        case ritual
        case commitment
        case projection
        case ratingPrompt
    }

    // MARK: - Published Properties
    @Published var currentStep: Step = .epigraph
    @Published var selectedDaysPerWeek: Int = 5

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
    /// commitment and finish.
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

    /// Bypasses the rest of the flow. Nothing from it (including any
    /// commitment already picked) is persisted.
    func skip() {
        completeOnboarding()
    }

    // MARK: - Private Methods

    private func finishRitualSteps() {
        storageService.setWeeklyCommitmentDaysPerWeek(selectedDaysPerWeek)
        completeOnboarding()
    }

    private func completeOnboarding() {
        storageService.setHasSeenOnboarding(true)
        onComplete?()
    }
}
