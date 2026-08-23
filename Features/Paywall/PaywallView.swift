import SwiftUI

/// Paywall screen — always a custom SwiftUI build, deliberately not
/// RevenueCat's hosted template (see git history: the app tried that once
/// and reverted it for design control).
///
/// The one screen in the app that's light, not dark: the rest of Verg is
/// candle-dark by design (write at night, phone face down), but Ascent is
/// the summit — you climb out of the dark into daylight. `AscentPalette`
/// is a local light palette scoped to this screen only; Theme.swift stays
/// dark for everywhere else. The warm flame gradient (FFCC00->FF9500) is
/// the one thread carried over, and it reads even better against white.
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

// MARK: - Ascent Palette (local, light — not part of the app-wide dark Theme)
private enum AscentPalette {
    static let background = Color(hex: "FFFFFF")
    static let summitGlow = Color(hex: "FFF4D6")
    static let cardBackground = Color(hex: "F8F6F2")
    static let cardBorder = Color(hex: "EBE7DF")
    static let primaryText = Color(hex: "16140F")
    static let secondaryText = Color(hex: "6B6660")
    static let flameTop = Color(hex: "FFCC00")
    static let flameBottom = Color(hex: "FF9500")
    static let flameGradient = LinearGradient(
        colors: [flameTop, flameBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// The actual paywall content.
struct NativePaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel

    var body: some View {
        ZStack {
            AscentPalette.background
                .ignoresSafeArea()

            summitGlow

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
        .preferredColorScheme(.light)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Summit Glow
    /// Soft warm light from above — dawn at the summit, not a celebration
    /// glow. Subtler than the dark screens' glows since it's sitting on
    /// white, not black.
    private var summitGlow: some View {
        RadialGradient(
            colors: [
                AscentPalette.summitGlow.opacity(0.9),
                AscentPalette.summitGlow.opacity(0.25),
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
                        .foregroundColor(AscentPalette.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(AscentPalette.cardBackground)
                        .overlay(Circle().stroke(AscentPalette.cardBorder, lineWidth: 1))
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
                .foregroundStyle(AscentPalette.flameGradient)
                .shadow(color: AscentPalette.flameBottom.opacity(0.35), radius: 16)

            Text("The Ascent")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(AscentPalette.primaryText)

            Text("Your full archive. Your stats. Your pace.")
                .font(Theme.Typography.body)
                .foregroundColor(AscentPalette.secondaryText)
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
                        .foregroundStyle(AscentPalette.flameGradient)
                        .frame(width: 32)

                    Text(feature.text)
                        .font(Theme.Typography.body)
                        .foregroundColor(AscentPalette.primaryText)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
                .background(AscentPalette.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(AscentPalette.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Supporting Features (smaller — also included)
    private var supportingFeatureRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("ALSO INCLUDED")
                .font(Theme.Typography.caption.weight(.semibold))
                .tracking(1)
                .foregroundColor(AscentPalette.secondaryText.opacity(0.8))

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(viewModel.supportingFeatures) { feature in
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14))
                            .foregroundColor(AscentPalette.flameBottom)
                            .frame(width: 20)

                        Text(feature.text)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(AscentPalette.secondaryText)
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
    /// Solid dark button — the strongest possible contrast against the
    /// white page, and a deliberate visual echo of the app's own dark
    /// theme showing through at the moment you commit to the climb.
    private var ctaSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button {
                viewModel.purchase()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.selectedPlanHasFreeTrial ? "Start Free Trial" : "Continue")
                            .font(Theme.Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Layout.buttonHeight)
                .foregroundColor(.white)
                .background(AscentPalette.primaryText)
                .cornerRadius(Theme.CornerRadius.medium)
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.6 : 1)

            Text(viewModel.selectedPlanHasFreeTrial
                ? "Free trial auto-renews at \(viewModel.selectedPlan == .yearly ? viewModel.yearlyPrice + "/year" : viewModel.monthlyPrice + "/month") unless cancelled."
                : "Subscription auto-renews unless cancelled.")
                .font(Theme.Typography.caption)
                .foregroundColor(AscentPalette.secondaryText)
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
            .foregroundColor(AscentPalette.primaryText)

            HStack(spacing: Theme.Spacing.xxs) {
                Link("Terms", destination: URL(string: "https://nolanwolfe.github.io/verg/terms")!)
                Text("•")
                Link("Privacy", destination: URL(string: "https://nolanwolfe.github.io/verg/privacy")!)
            }
            .font(Theme.Typography.caption)
            .foregroundColor(AscentPalette.secondaryText.opacity(0.8))
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
                            .foregroundColor(AscentPalette.primaryText)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, Theme.Spacing.xxs)
                                .padding(.vertical, 3)
                                .background(AscentPalette.flameBottom.opacity(0.15))
                                .foregroundColor(AscentPalette.flameBottom)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(AscentPalette.secondaryText)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(Theme.Typography.title2)
                        .foregroundColor(AscentPalette.primaryText)
                    Text(period)
                        .font(Theme.Typography.caption)
                        .foregroundColor(AscentPalette.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
            .background(AscentPalette.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(isSelected ? AscentPalette.flameBottom : AscentPalette.cardBorder, lineWidth: isSelected ? 2 : 1)
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
