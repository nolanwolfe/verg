import SwiftUI

/// Paywall screen — always a custom SwiftUI build, deliberately not
/// RevenueCat's hosted template (see git history: the app tried that once
/// and reverted it for design control). Matches the dark/warm-gradient
/// visual language used everywhere else in the app (candle flame colors,
/// Theme.swift tokens) rather than system colors.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseService: PurchaseService
    @StateObject private var viewModel = PaywallViewModel()

    var onSubscribed: (() -> Void)?

    var body: some View {
        NativePaywallView(viewModel: viewModel)
            .onAppear {
                viewModel.purchaseService = purchaseService
                viewModel.onDismiss = { dismiss() }
                viewModel.onSubscribed = {
                    onSubscribed?()
                    dismiss()
                }
            }
    }
}

/// The actual paywall content.
struct NativePaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ascentGlow

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    header

                    heroFeatureCards

                    supportingFeatureRow

                    planSelection

                    ctaSection

                    restoreAndLegal
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }

            closeButton
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Ambient Glow
    private var ascentGlow: some View {
        RadialGradient(
            colors: [
                Color(hex: "FF9500").opacity(0.18),
                Color(hex: "FF7000").opacity(0.06),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0),
            startRadius: 10,
            endRadius: 420
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Close Button
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    viewModel.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(Circle())
                }
                .padding(.trailing, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
            }
            Spacer()
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FFCC00"), Color(hex: "FF9500")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(hex: "FF9500").opacity(0.45), radius: 16)

            Text("The Ascent")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)

            Text("Your full archive. Your stats. Your pace.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Hero Features (the actual sell — archive + stats)
    private var heroFeatureCards: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(viewModel.heroFeatures) { feature in
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FFCC00"), Color(hex: "FF9500")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 32)

                    Text(feature.text)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
            }
        }
    }

    // MARK: - Supporting Features (smaller — also included)
    private var supportingFeatureRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("ALSO INCLUDED")
                .font(Theme.Typography.caption.weight(.semibold))
                .tracking(1)
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(viewModel.supportingFeatures) { feature in
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.accent)
                            .frame(width: 20)

                        Text(feature.text)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xxs)
    }

    // MARK: - Plan Selection
    private var planSelection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PlanCard(
                title: "Yearly",
                price: viewModel.yearlyPrice,
                period: "/year",
                badge: "Best Value",
                subtitle: viewModel.yearlyTrialDisclosure,
                isSelected: viewModel.selectedPlan == .yearly,
                onTap: { viewModel.selectPlan(.yearly) }
            )

            PlanCard(
                title: "Monthly",
                price: viewModel.monthlyPrice,
                period: "/month",
                badge: nil,
                subtitle: viewModel.monthlyTrialDisclosure,
                isSelected: viewModel.selectedPlan == .monthly,
                onTap: { viewModel.selectPlan(.monthly) }
            )
        }
    }

    // MARK: - CTA
    private var ctaSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button {
                viewModel.purchase()
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color(hex: "000000"))
                } else {
                    Text(viewModel.selectedPlanHasFreeTrial ? "Start Free Trial" : "Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !viewModel.isLoading))
            .disabled(viewModel.isLoading)

            Text(viewModel.selectedPlanHasFreeTrial
                ? "Free trial auto-renews at \(viewModel.selectedPlan == .yearly ? viewModel.yearlyPrice + "/year" : viewModel.monthlyPrice + "/month") unless cancelled."
                : "Subscription auto-renews unless cancelled.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Restore & Legal
    private var restoreAndLegal: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("Restore Purchases") {
                viewModel.restorePurchases()
            }
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.primaryText)

            HStack(spacing: Theme.Spacing.xxs) {
                Link("Terms", destination: URL(string: "https://nolanwolfe.github.io/verg/terms")!)
                Text("•")
                Link("Privacy", destination: URL(string: "https://nolanwolfe.github.io/verg/privacy")!)
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
        }
    }
}

/// Individual plan selection card
struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text(title)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, Theme.Spacing.xxs)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.accent.opacity(0.2))
                                .foregroundColor(Theme.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(period)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(isSelected ? Theme.Colors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
        .environmentObject(PurchaseService.shared)
}
