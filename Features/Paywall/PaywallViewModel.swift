import Foundation
import Combine
import UIKit

/// ViewModel for the Paywall screen
@MainActor
final class PaywallViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var selectedPlan: PlanType = .yearly
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Plan Types
    enum PlanType: String, CaseIterable {
        case monthly
        case yearly

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        var period: String {
            switch self {
            case .monthly: return "/month"
            case .yearly: return "/year"
            }
        }

        var isBestValue: Bool {
            self == .yearly
        }
    }

    // MARK: - Features
    struct Feature: Identifiable {
        let id = UUID()
        /// SF Symbol name, rendered in the gold gradient. Ignored when
        /// `emoji` is set.
        let icon: String
        /// Draws the app's own procedural candle flame instead of an SF
        /// Symbol. An actual 🕯️ emoji can't be tinted, so it clashed with
        /// the gold glyphs on the other rows; this matches them.
        var usesCandleMark: Bool = false
        let text: String
    }

    // Sells the archive and the stats — not a generic feature list. Copy
    // per VOICE.md: short declaratives, concrete nouns, no sales pressure.
    // The relight row states the mechanic without gamified framing.
    let heroFeatures: [Feature] = [
        Feature(icon: "books.vertical.fill", text: "A full collection of your journals. Every page and every book, kept private to you."),
        Feature(icon: "flame.fill", usesCandleMark: true, text: "Real paper progress of who you're becoming, and insights to prove it."),
        Feature(icon: "slider.horizontal.3", text: "Customization, ambience, prompts, candle wicks, session length, year-by-year facts.")
    ]

    // MARK: - Dependencies
    var purchaseService: PurchaseService = .shared

    // MARK: - Context-aware subtitle
    /// Set by the presenting view when the paywall opened from a tap on a
    /// specific locked page. A date formats to "March 14th is still here."
    /// — naming the exact thing the person reached for and confirming
    /// it's safe. Nil falls back to the generic subtitle.
    var contextSubtitleDate: Date?

    var subtitleText: String {
        if let date = contextSubtitleDate {
            let day = date.formatted(.dateTime.month().day())
            return String(format: AppStrings.Paywall.contextSubtitleFormat, day)
        }
        return AppStrings.Paywall.subtitle
    }

    // MARK: - Callbacks
    var onDismiss: (() -> Void)?
    var onSubscribed: (() -> Void)?

    // MARK: - Dynamic Prices from PurchaseService (never hardcoded — all
    // sourced from RevenueCat's offerings at runtime, see PurchaseService)
    var monthlyPrice: String {
        purchaseService.monthlyPrice
    }

    var yearlyPrice: String {
        purchaseService.yearlyPrice
    }

    /// Yearly's price divided by 12 — the equivalence shown prominently
    /// on the Yearly row, comparable at a glance to Monthly's own price.
    var yearlyMonthlyEquivalentPrice: String {
        purchaseService.yearlyMonthlyEquivalentPrice
    }

    var monthlyIntroOffer: String? {
        purchaseService.monthlyIntroOffer
    }

    var yearlyIntroOffer: String? {
        purchaseService.yearlyIntroOffer
    }

    /// Whether THIS subscriber can actually get Yearly's trial — false for
    /// a lapsed subscriber even if the product still has an offer configured.
    var yearlyIntroEligible: Bool {
        purchaseService.yearlyIntroEligible
    }

    /// Whether Yearly's trial should be shown at all right now.
    private var yearlyTrialAvailable: Bool {
        yearlyIntroOffer != nil && yearlyIntroEligible
    }

    /// Yearly row's subtitle: the trial disclosure when eligible, or the
    /// plain per-year price with no trial line when not (e.g. a lapsed
    /// subscriber) — the price still appears, just not twice on the row,
    /// since the equivalence on the right is the only other number shown.
    var yearlySubtitle: String {
        if yearlyTrialAvailable, let offer = yearlyIntroOffer {
            return "\(offer), then \(yearlyPrice)/year"
        }
        return "\(yearlyPrice)/year"
    }

    /// Whether the CURRENTLY SELECTED plan has a trial available right
    /// now — trial is yearly-only AND eligibility-gated, so this must not
    /// just check "does the product have an offer," or a lapsed
    /// subscriber would still see "Start Free Trial" for a trial they
    /// can't actually get.
    var selectedPlanHasFreeTrial: Bool {
        switch selectedPlan {
        case .monthly: return false
        case .yearly: return yearlyTrialAvailable
        }
    }

    /// e.g. "Start 3 days free" — built from the real offer text
    /// ("3 days free"), never a hardcoded duration.
    var ctaTitle: String {
        guard selectedPlanHasFreeTrial, let offer = yearlyIntroOffer else {
            return AppStrings.Paywall.ctaTitle
        }
        return "\(AppStrings.Paywall.ctaTitle) — \(offer)"
    }

    // MARK: - Initialization
    init(purchaseService: PurchaseService = .shared) {
        self.purchaseService = purchaseService
    }

    // MARK: - Actions
    func selectPlan(_ plan: PlanType) {
        selectedPlan = plan
    }

    func startTrial() {
        purchase()
    }

    func purchase() {
        isLoading = true
        errorMessage = nil

        Task {
            let success: Bool

            switch selectedPlan {
            case .monthly:
                success = await purchaseService.purchaseMonthly()
            case .yearly:
                success = await purchaseService.purchaseYearly()
            }

            isLoading = false

            if success {
                onSubscribed?()
            } else if let error = purchaseService.errorMessage {
                errorMessage = error
                showError = true
            }
        }
    }

    func restorePurchases() {
        isLoading = true
        errorMessage = nil

        Task {
            let success = await purchaseService.restorePurchases()

            isLoading = false

            if success {
                onSubscribed?()
            } else {
                errorMessage = "No purchases found to restore."
                showError = true
            }
        }
    }

    func dismiss() {
        onDismiss?()
    }

    // MARK: - URL Actions
    func openPrivacyPolicy() {
        if let url = URL(string: "https://nolanwolfe.github.io/verg/privacy") {
            UIApplication.shared.open(url)
        }
    }

    func openTermsOfService() {
        if let url = URL(string: "https://nolanwolfe.github.io/verg/terms") {
            UIApplication.shared.open(url)
        }
    }
}
