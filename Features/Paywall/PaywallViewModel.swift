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
        /// SF Symbol name, rendered in the gold gradient at a single light
        /// weight for every row.
        let icon: String
        let text: String
    }

    // Sells the archive and the stats — not a generic feature list. Copy
    // per VOICE.md: short declaratives, concrete nouns, no sales pressure.
    // The relight row states the mechanic without gamified framing.
    let heroFeatures: [Feature] = [
        // All three are line-drawn at the same weight. The filled book stack
        // and the candle mark were heavier than the sliders beside them, so
        // the row read as three unrelated marks; outlined, they read as a set
        // and the eye goes to the words instead of the icons.
        Feature(icon: "books.vertical", text: "A full collection of your journals. Every page and every book, kept private to you."),
        Feature(icon: "doc.text", text: "Real progress of who you're becoming, and insights to prove it."),
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

    /// The line above the title. When the paywall was opened by tapping a
    /// specific locked page, it names that page instead — "March 14th is
    /// still here." earns its place over a generic instruction.
    var leadText: String {
        contextSubtitleDate == nil ? AppStrings.Paywall.lead : subtitleText
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

    /// The trial, as the thing the eye should land on. Nil when this
    /// subscriber can't actually have it, so a lapsed subscriber is never
    /// shown a free trial they'd be refused at the till.
    var yearlyTrialHeadline: String? {
        guard yearlyTrialAvailable, let offer = yearlyIntroOffer else { return nil }
        return "\(offer) free trial"
    }

    /// What they will actually be charged, and when.
    ///
    /// This stays on screen even while the trial is the loud part. App Review
    /// 3.1.2 wants the price after an introductory offer disclosed on the
    /// screen that sells it, and "$4.99/mo" on the right of the row is a
    /// per-month equivalence, not the amount that leaves their account. Drop
    /// this line and the real figure appears nowhere.
    var yearlySubtitle: String {
        if yearlyTrialAvailable {
            return "then \(yearlyPrice)/year"
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

    /// e.g. "The Golden Age — 3 days free". Built from the real trial length
    /// reported by StoreKit, never a hardcoded duration.
    var ctaTitle: String {
        guard selectedPlanHasFreeTrial, let offer = yearlyIntroOffer else {
            return AppStrings.Paywall.ctaTitle
        }
        return "\(AppStrings.Paywall.ctaTitle) — \(offer) free"
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
