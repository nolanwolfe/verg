import Foundation
import Combine
import UIKit

/// ViewModel for the Paywall screen
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

        var price: String {
            switch self {
            case .weekly: return "$4.99"
            case .yearly: return "$99.99"
            }
        }

        var period: String {
            switch self {
            case .weekly: return "/week"
            case .yearly: return "/year"
            }
        }

        var description: String {
            switch self {
            case .weekly: return "Billed weekly"
            case .yearly: return "Save 61%"
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
        Feature(icon: "checkmark.circle.fill", text: "10-minute focused writing sessions"),
        Feature(icon: "checkmark.circle.fill", text: "Track your daily streak"),
        Feature(icon: "checkmark.circle.fill", text: "Build a gallery of your pages"),
        Feature(icon: "checkmark.circle.fill", text: "Daily reminders to write")
    ]

    // MARK: - Dependencies
    private let purchaseService: PurchaseService

    // MARK: - Callbacks
    var onDismiss: (() -> Void)?
    var onSubscribed: (() -> Void)?

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

            await MainActor.run {
                isLoading = false

                if success {
                    onSubscribed?()
                } else {
                    errorMessage = purchaseService.errorMessage ?? "Purchase failed. Please try again."
                    showError = true
                }
            }
        }
    }

    func restorePurchases() {
        isLoading = true
        errorMessage = nil

        Task {
            let success = await purchaseService.restorePurchases()

            await MainActor.run {
                isLoading = false

                if success {
                    onSubscribed?()
                } else {
                    errorMessage = "No purchases found to restore."
                    showError = true
                }
            }
        }
    }

    func dismiss() {
        onDismiss?()
    }

    // MARK: - URL Actions
    func openPrivacyPolicy() {
        if let url = URL(string: "https://yourapp.com/privacy") {
            UIApplication.shared.open(url)
        }
    }

    func openTermsOfService() {
        if let url = URL(string: "https://yourapp.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}
