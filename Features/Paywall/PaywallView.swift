import SwiftUI

/// Paywall screen — always a custom SwiftUI build, deliberately not
/// RevenueCat's hosted template (see git history: the app tried that once
/// and reverted it for design control).
///
/// The one screen in the app that's light, not dark: the rest of Verg is
/// candle-dark by design (write at night, phone face down), but Ascent is
/// the summit — you climb out of the dark into daylight. `AscentPalette`
/// is a local warm-paper light palette scoped to this screen only;
/// Theme.swift stays dark for everywhere else.
///
/// Single screen, no scrolling, fits down to iPhone SE — see
/// `isCompact` below. If the "also included" line has to go to make that
/// true, it goes; the CTA and footer never do.
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

// MARK: - Ascent Palette (local, warm-light — not part of the app-wide dark Theme)
// Per design.md: SF Pro (Theme.Typography already is), 8pt spacing base,
// 12pt continuous corners, warm palette only — wax/ember/paper, no purple,
// no cool gray, no glowing borders.
enum AscentPalette {
    static let background = Color(hex: "FFFCF6")       // paper, not stark white
    static let summitGlow = Color(hex: "FFF1D6")
    static let cardBackground = Color(hex: "F9F5EC")
    static let cardBorder = Color(hex: "EAE2D2")
    static let primaryText = Color(hex: "1E1B14")
    static let secondaryText = Color(hex: "746C5E")     // warm gray, not cool
    static let waxColor = Color(hex: "FFF8E7")
    static let flameTop = Color(hex: "FFCC00")          // ember
    static let flameBottom = Color(hex: "FF9500")       // ember
    static let flameGradient = LinearGradient(colors: [flameTop, flameBottom], startPoint: .top, endPoint: .bottom)
    static let cornerRadius: CGFloat = 12
}

/// The actual paywall content.
struct NativePaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel

    var body: some View {
        GeometryReader { geo in
            // geo.size already excludes the safe area (status bar / home
            // indicator), so this is genuinely available content height.
            // SE's ~647pt of available height fits everything, including
            // "Also included" — this threshold is a safety net for a
            // smaller class of device, not something SE itself should hit.
            let isCompact = geo.size.height < 600

            ZStack {
                AscentPalette.background.ignoresSafeArea()
                summitGlow

                VStack(spacing: 0) {
                    header
                        .padding(.top, isCompact ? Theme.Spacing.md : Theme.Spacing.lg)

                    Spacer(minLength: Theme.Spacing.sm)

                    heroFeatureCards

                    Spacer(minLength: Theme.Spacing.xs)

                    // "Also included" is the first thing to go if a screen
                    // genuinely can't fit it — never the CTA or footer.
                    if !isCompact {
                        supportingFeatureLine
                    }

                    Spacer(minLength: Theme.Spacing.sm)

                    planSelection

                    Spacer(minLength: Theme.Spacing.sm)

                    ctaSection

                    footer
                        .padding(.top, Theme.Spacing.xs)
                        .padding(.bottom, Theme.Spacing.xxs)
                }
                .padding(.horizontal, Theme.Spacing.md)

                closeButton
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong")
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Summit Glow
    private var summitGlow: some View {
        RadialGradient(
            colors: [AscentPalette.summitGlow.opacity(0.8), AscentPalette.summitGlow.opacity(0.2), Color.clear],
            center: UnitPoint(x: 0.5, y: 0),
            startRadius: 10,
            endRadius: 380
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Close Button
    /// 44x44 tap target per HIG, even though the visible glyph is smaller.
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    viewModel.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AscentPalette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(AscentPalette.cardBackground)
                        .overlay(Circle().stroke(AscentPalette.cardBorder, lineWidth: 1))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, Theme.Spacing.xs)
                .padding(.top, Theme.Spacing.xxs)
            }
            Spacer()
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            PaywallIcon()

            Text(AppStrings.Paywall.title)
                .font(Theme.Typography.title)
                .foregroundColor(AscentPalette.primaryText)
                .multilineTextAlignment(.center)

            Text("Your full archive. Your stats. Your pace.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(AscentPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Hero Features (the actual sell — archive + stats)
    private var heroFeatureCards: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            ForEach(viewModel.heroFeatures) { feature in
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(AscentPalette.flameGradient)
                        .frame(width: 22)

                    Text(feature.text)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(AscentPalette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous)
                        .fill(AscentPalette.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous)
                        .stroke(AscentPalette.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Supporting Features (compressed to one line — cut first if space is tight)
    private var supportingFeatureLine: some View {
        Text(viewModel.supportingFeatures.map(\.text).joined(separator: "  ·  "))
            .font(Theme.Typography.caption)
            .foregroundColor(AscentPalette.secondaryText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Plan Selection
    private var planSelection: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            PlanCard(
                title: "Yearly",
                price: viewModel.yearlyMonthlyEquivalentPrice,
                period: "/mo",
                badge: nil,
                subtitle: viewModel.yearlySubtitle,
                isSelected: viewModel.selectedPlan == .yearly,
                onTap: { viewModel.selectPlan(.yearly) }
            )

            PlanCard(
                title: "Monthly",
                price: viewModel.monthlyPrice,
                period: "/mo",
                badge: nil,
                subtitle: nil,
                isSelected: viewModel.selectedPlan == .monthly,
                onTap: { viewModel.selectPlan(.monthly) }
            )
        }
    }

    // MARK: - CTA
    /// Solid dark button — the strongest contrast against the white page,
    /// and a deliberate echo of the app's own dark theme at the moment
    /// you commit to the climb.
    private var ctaSection: some View {
        Button {
            viewModel.purchase()
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(viewModel.ctaTitle)
                        .font(Theme.Typography.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous)
                    .fill(AscentPalette.primaryText)
            )
        }
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.6 : 1)
    }

    // MARK: - Footer
    /// One line: Restore Purchases · Terms · Privacy.
    private var footer: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Button("Restore Purchases") {
                viewModel.restorePurchases()
            }
            Text("·")
            Link("Terms", destination: URL(string: "https://nolanwolfe.github.io/verg/terms")!)
            Text("·")
            Link("Privacy", destination: URL(string: "https://nolanwolfe.github.io/verg/privacy")!)
        }
        .font(Theme.Typography.caption)
        .foregroundColor(AscentPalette.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
    }
}

/// Individual plan selection card — price appears exactly once, on the
/// right. Yearly's subtitle carries the trial/full-price disclosure;
/// Monthly has none, per "shown plainly."
struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let subtitle: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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

                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.caption)
                            .foregroundColor(AscentPalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
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
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous)
                    .fill(AscentPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous)
                    .stroke(isSelected ? AscentPalette.flameBottom : AscentPalette.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paywall Icon
/// The real Verg app icon — its own dark backdrop is contained within its
/// own rounded frame, so it reads cleanly against the light paywall
/// background. Static: it's raster artwork, not a procedural flame, so it
/// doesn't animate here (contrast with the in-session candle).
struct PaywallIcon: View {
    var body: some View {
        Image("VergIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AscentPalette.cornerRadius, style: .continuous)
                    .stroke(AscentPalette.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
        .environmentObject(PurchaseService.shared)
}
