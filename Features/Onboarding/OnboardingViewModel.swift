import Foundation
import Combine
import SwiftUI

/// ViewModel for the Onboarding flow
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var currentPage: Int = 0
    @Published var showPaywall: Bool = false

    // MARK: - Constants
    let totalPages = 3

    // MARK: - Dependencies
    private let storageService: StorageService

    // MARK: - Callbacks
    var onComplete: (() -> Void)?

    // MARK: - Initialization
    init(storageService: StorageService = .shared) {
        self.storageService = storageService
    }

    // MARK: - Computed Properties
    var isLastPage: Bool {
        currentPage == totalPages - 1
    }

    var continueButtonText: String {
        isLastPage ? "Get Started" : "Continue"
    }

    // MARK: - Actions

    /// Advance to next page or complete onboarding
    func continueAction() {
        if isLastPage {
            completeOnboarding()
        } else {
            withAnimation(Theme.Animation.standard) {
                currentPage += 1
            }
        }
    }

    /// Skip directly to completion
    func skip() {
        completeOnboarding()
    }

    // MARK: - Private Methods

    private func completeOnboarding() {
        // Mark onboarding as seen
        storageService.setHasSeenOnboarding(true)

        // Navigate to paywall
        showPaywall = true
    }
}
