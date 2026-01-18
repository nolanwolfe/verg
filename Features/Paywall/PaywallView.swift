import SwiftUI

/// Paywall screen for subscription
struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    @Environment(\.dismiss) private var dismiss

    var onSubscribed: (() -> Void)?

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    // Close button
                    closeButton

                    // Header with candle
                    headerSection

                    // Features list
                    featuresSection

                    // Pricing cards
                    pricingSection

                    // CTA button
                    ctaButton

                    // Restore purchases
                    restoreButton

                    // Legal links
                    legalLinks
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxxl)
            }

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            viewModel.onSubscribed = {
                onSubscribed?()
                dismiss()
            }
            viewModel.onDismiss = {
                dismiss()
            }
        }
    }

    // MARK: - Close Button
    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Candle icon
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.accentGradient)
                .padding(.bottom, Theme.Spacing.sm)

            Text("Start Your Writing Ritual")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)

            Text("Build a daily journaling habit with focused writing sessions")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(viewModel.features) { feature in
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: feature.icon)
                        .foregroundColor(Theme.Colors.accent)
                        .font(.system(size: 20))

                    Text(feature.text)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .fillWidth(alignment: .leading)
        .cardStyle()
    }

    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(PaywallViewModel.PlanType.allCases, id: \.rawValue) { plan in
                PricingCard(
                    plan: plan,
                    isSelected: viewModel.selectedPlan == plan,
                    onSelect: { viewModel.selectPlan(plan) }
                )
            }
        }
    }

    // MARK: - CTA Button
    private var ctaButton: some View {
        Button {
            viewModel.startTrial()
        } label: {
            Text("Start 3-Day Free Trial")
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            viewModel.restorePurchases()
        } label: {
            Text("Restore Purchases")
        }
        .buttonStyle(TextLinkButtonStyle())
    }

    // MARK: - Legal Links
    private var legalLinks: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button("Terms") {
                viewModel.openTermsOfService()
            }
            .buttonStyle(TextLinkButtonStyle())

            Button("Privacy") {
                viewModel.openPrivacyPolicy()
            }
            .buttonStyle(TextLinkButtonStyle())
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryText))
                .scaleEffect(1.5)
        }
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    let plan: PaywallViewModel.PlanType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    HStack {
                        Text(plan.title)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)

                        if plan.isBestValue {
                            Text("BEST VALUE")
                                .font(Theme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.primaryText)
                                .padding(.horizontal, Theme.Spacing.xxs)
                                .padding(.vertical, Theme.Spacing.xxxs)
                                .background(Theme.Colors.accentGradient)
                                .cornerRadius(Theme.CornerRadius.small / 2)
                        }
                    }

                    Text(plan.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(plan.price)
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(plan.period)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(
                        isSelected ? Theme.Colors.accent : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
}
