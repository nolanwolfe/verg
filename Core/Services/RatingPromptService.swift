import Foundation
import StoreKit
import UIKit

/// Triggers the system rating prompt — never a custom "rate us" button, per
/// Apple's guidelines and the app's own "no engagement bait" rule. Called
/// from exactly two places: the onboarding rating screen, and after the
/// bell on day 3 of a lit candle. Never on cold launch.
@MainActor
enum RatingPromptService {
    /// In-memory only — resets on every launch, which is what makes "never
    /// twice a session" mean "twice this process," not "twice ever."
    private static var hasRequestedThisSession = false

    static func requestReviewIfAppropriate() {
        guard !hasRequestedThisSession else { return }
        hasRequestedThisSession = true

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    #if DEBUG
    /// Test-only reset so unit tests don't depend on execution order.
    static func resetForTesting() {
        hasRequestedThisSession = false
    }
    #endif
}
