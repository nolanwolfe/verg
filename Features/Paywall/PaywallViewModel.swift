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
        case weekly
        case yearly

        var title: String {
            switch self {
            case .weekly: return "Weekly"
            case .yearly: return "Yearly"
            }
        }

        var period: String {
            switch self {
            case .weekly: return "/week"
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
        let icon: String
        let text: String
    }

    let features: [Feature] = [
        Feature(icon: "checkmark.circle.fill", text: "Daily focused writing sessions"),
        Feature(icon: "checkmark.circle.fill", text: "Track your daily streak"),
        Feature(icon: "checkmark.circle.fill", text: "Build a gallery of your pages"),
        Feature(icon: "checkmark.circle.fill", text: "Daily reminders to write")
    ]

    // MARK: - Dependencies
    var purchaseService: PurchaseService = .shared

    // MARK: - Callbacks
    var onDismiss: (() -> Void)?
    var onSubscribed: (() -> Void)?

    // MARK: - Dynamic Prices from PurchaseService
    var weeklyPrice: String {
        purchaseService.weeklyPrice
    }

    var yearlyPrice: String {
        purchaseService.yearlyPrice
    }

    var weeklyIntroOffer: String? {
        purchaseService.weeklyIntroOffer
    }

    var yearlyIntroOffer: String? {
        purchaseService.yearlyIntroOffer
    }

    /// Full trial disclosure text, e.g. "3 days free, then $3.99/week"
    var weeklyTrialDisclosure: String {
        if let offer = purchaseService.weeklyIntroOffer {
            return "\(offer), then \(purchaseService.weeklyPrice)/week"
        }
        return "\(purchaseService.weeklyPrice)/week"
    }

    var yearlyTrialDisclosure: String {
        if let offer = purchaseService.yearlyIntroOffer {
            return "\(offer), then \(purchaseService.yearlyPrice)/year"
        }
        return "\(purchaseService.yearlyPrice)/year"
    }

    /// Whether any plan has a free trial
    var hasFreeTrial: Bool {
        weeklyIntroOffer != nil || yearlyIntroOffer != nil
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
            case .weekly:
                success = await purchaseService.purchaseWeekly()
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
