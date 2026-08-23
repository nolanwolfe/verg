import SwiftUI
import UIKit

/// Paywall screen — always a custom SwiftUI build, deliberately not
/// RevenueCat's hosted template (see git history: the app tried that once
/// and reverted it for design control).
///
/// The one screen in the app that's light, not dark: the rest of Verg is
/// candle-dark by design (write at night, phone face down), but the Golden Age is
/// the summit — you climb out of the dark into daylight. `GoldenPalette`
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

    /// The date of the locked page the user tapped, when the paywall was
    /// opened by a reach for something specific. Drives the context-aware
    /// subtitle ("March 14th is still here.") — provably true, speaking to
    /// the exact thing they came for. Nil = generic subtitle.
    var lockedPageDate: Date?

    var onSubscribed: (() -> Void)?

    var body: some View {
        NativePaywallView(viewModel: viewModel)
            .onAppear {
                viewModel.contextSubtitleDate = lockedPageDate
                viewModel.purchaseService = purchaseService
                viewModel.onDismiss = { dismiss() }
                viewModel.onSubscribed = {
                    onSubscribed?()
                    dismiss()
                }
            }
    }
}

// MARK: - Golden Palette (local, warm-light — not part of the app-wide dark Theme)
// Per design.md: SF Pro (Theme.Typography already is), 8pt spacing base,
// 12pt continuous corners, warm palette only — wax/ember/paper, no cool
// gray, no glowing borders. The single purple on this screen is the app
// icon itself, which is the mark and stays as drawn.
enum GoldenPalette {
    /// The paywall is always the opposite of the app. In a dark app it is the
    /// break of daylight; in a light app it becomes the one dark room, which
    /// keeps it the same gesture either way — you step out of wherever you
    /// were. `PaywallView` pins the inverted scheme, and because these are
    /// trait-resolved the "light" column below is simply what gets drawn when
    /// that inversion lands on light.
    private static func inverting(_ light: String, _ dark: String) -> Color {
        Theme.Colors.adaptive(light: light, dark: dark)
    }

    static let background = inverting("FFFDF9", "0B0A08")       // paper / lamplit black
    static let crown = inverting("FFFFFF", "2A2113")            // the break of light, top of frame
    static let haloGold = inverting("FFDE9B", "8A6A22")         // the gold in the opening
    static let summitGlow = inverting("FFF4E0", "17130C")
    static let cardBackground = inverting("FBF7EF", "17150F")
    static let cardBorder = inverting("EDE5D6", "2E2A20")
    static let primaryText = inverting("1E1B14", "F7F1E2")
    static let secondaryText = inverting("746C5E", "9A9184")     // warm gray, not cool
    static let waxColor = Color(hex: "FFF8E7")
    static let flameTop = Color(hex: "FFCC00")          // ember
    static let flameBottom = Color(hex: "FF9500")       // ember
    static let flameGradient = LinearGradient(colors: [flameTop, flameBottom], startPoint: .top, endPoint: .bottom)
    /// Deeper than `flameGradient` so white text clears contrast on it —
    /// the pale ember yellow alone is far too light to sit white on.
    static let ctaGradient = LinearGradient(
        colors: [
            inverting("E8A317", "E8B53A"),
            inverting("C67A0B", "B07E14")
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let cornerRadius: CGFloat = 12
}

/// The actual paywall content.
struct NativePaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel
    /// Whether the app itself is dark. Read from the setting rather than
    /// the environment: the paywall is often presented from Write or Verg,
    /// which pin themselves dark, and inheriting *their* scheme would make
    /// the paywall light even when the app is set to light.
    private var appIsDark: Bool {
        switch StorageService.shared.settings.appearance {
        case .dark: return true
        case .light: return false
        case .system: return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    /// The close glyph starts hidden; see `closeButton`.
    @State private var closeIsVisible = false
    @State private var closeHideTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            GoldenPalette.background.ignoresSafeArea()
            heavenLight

            VStack(spacing: 0) {
                // The descriptive half. On a normal iPhone this all fits and
                // nothing scrolls; on a short one it scrolls behind the fixed
                // block below, with a fade so the cut reads as continuing
                // rather than clipped.
                ScrollView(showsIndicators: false) {
                    // Spaced to be read, not to be crammed onto one screen.
                    // It scrolls if it has to — the buy controls below never
                    // move, so nothing important is ever out of reach.
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        heroFeatureCards
                        reviewStack
                        LaurelBadge(text: AppStrings.Paywall.laurelBadge)
                            .padding(.top, Theme.Spacing.xxs)
                    }
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                    }
                )

                // Fixed from Yearly down — plans, button, assurance, links.
                // These never move, whatever the scroll above is doing.
                VStack(spacing: Theme.Spacing.xs) {
                    planSelection
                    ctaSection
                    footer
                }
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.xxs)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)

            closeButton
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong")
        }
        // The reverse of wherever the app is. `colorScheme` here is the
        // resolved scheme inherited from the app root — including the case
        // where the setting is "System" and the phone decided it.
        .preferredColorScheme(appIsDark ? .light : .dark)
    }

    private var reviewStack: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(AppStrings.Paywall.reviews.enumerated()), id: \.offset) { _, review in
                PaywallReviewCard(review: review)
            }
        }
    }

    // MARK: - Heaven Light
    /// The opening overhead: white at the crown of the frame falling into
    /// gold, then into paper. Two layers — a vertical wash for the shape of
    /// the light and a tight radial for the bright point it comes from.
    private var heavenLight: some View {
        ZStack {
            LinearGradient(
                colors: [
                    GoldenPalette.crown,
                    GoldenPalette.summitGlow,
                    GoldenPalette.background
                ],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [
                    GoldenPalette.haloGold.opacity(0.60),
                    GoldenPalette.haloGold.opacity(0.18),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.02),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Close Button
    /// Hidden until the corner is touched. The tap target is always live at
    /// the full 44x44 — the first tap reveals the glyph, the second closes.
    /// It re-hides on its own so the screen goes back to being uninterrupted.
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    if closeIsVisible {
                        viewModel.dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) { closeIsVisible = true }
                        hideCloseAfterDelay()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GoldenPalette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(GoldenPalette.cardBackground)
                        .overlay(Circle().stroke(GoldenPalette.cardBorder, lineWidth: 1))
                        .clipShape(Circle())
                        .opacity(closeIsVisible ? 1 : 0)
                        .frame(width: 44, height: 44)
                        // Always hittable, even while invisible.
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
                .padding(.trailing, Theme.Spacing.xs)
                .padding(.top, Theme.Spacing.xxs)
            }
            Spacer()
        }
    }

    private func hideCloseAfterDelay() {
        closeHideTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.3)) { closeIsVisible = false }
        }
        closeHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            PaywallIcon()

            // Lead first, title second: the two are one sentence, and the
            // title is its ending. Reversing them — title above, instructions
            // below — made the blank read as a headline with a caption under
            // it rather than a thought completing.
            Text(viewModel.leadText)
                .font(Theme.Typography.footnote)
                .foregroundColor(GoldenPalette.secondaryText)
                .multilineTextAlignment(.center)
                // Three commands, one size, wrapping to at most two lines.
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                // Without this the line gets offered a single-line width by
                // the surrounding stack and truncates mid-sentence instead
                // of wrapping to the second line it's allowed.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xs)

            Text(AppStrings.Paywall.title)
                .font(Theme.Typography.title2)
                .foregroundColor(GoldenPalette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xs)
        }
    }

    // MARK: - Hero Features (the actual sell — archive + stats)
    /// Quiet rows, not boxed cards: the paywall borrows the app's own
    /// plain-list language rather than a marketing-page card grid.
    private var heroFeatureCards: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(viewModel.heroFeatures) { feature in
                HStack(spacing: Theme.Spacing.xs) {
                    // One weight, one treatment, all three rows. `.light`
                    // keeps them as quiet as the sliders glyph, which was the
                    // only one already reading as a hairline mark.
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(GoldenPalette.flameGradient)
                        .frame(width: 20)

                    Text(feature.text)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(GoldenPalette.primaryText)
                        .lineLimit(5)
                        // Enough headroom to shrink a borderline row rather
                        // than truncate it mid-word on the narrowest screen.
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
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
                trialHeadline: viewModel.yearlyTrialHeadline,
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
    /// Gold, with white on top — the one saturated surface on the page,
    /// carrying the tier's own colour rather than borrowing the app's dark.
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
                RoundedRectangle(cornerRadius: GoldenPalette.cornerRadius, style: .continuous)
                    .fill(GoldenPalette.ctaGradient)
            )
            .shadow(color: GoldenPalette.flameBottom.opacity(0.35), radius: 12, x: 0, y: 4)
        }
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.6 : 1)
    }

    // MARK: - Footer
    /// One line: Restore Purchases · Terms · Privacy. Above it, the
    /// assurance — writing is free — because the guide says so plainly
    /// at the moment money is on the table.
    private var footer: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(AppStrings.Paywall.footerAssurance)
                .font(Theme.Typography.caption)
                .foregroundColor(GoldenPalette.secondaryText)

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
            .foregroundColor(GoldenPalette.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shiny Gold Text
/// Gold lettering with a highlight that travels across it, once every few
/// seconds — the way light moves over a gilded edge when the page tilts.
///
/// The sheen is a bright band inside the gradient rather than a white shape
/// laid over the glyphs, so the text never brightens as a whole and never
/// stops being readable. Under Reduce Motion it holds still and simply stays
/// gold: the point is to catch the eye, not to demand it.
struct ShinyGoldText: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: CGFloat = -1

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: GoldenPalette.flameBottom, location: 0),
                        .init(color: Color(hex: "FFE9A8"), location: max(0, sweep)),
                        .init(color: GoldenPalette.flameBottom, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                guard !reduceMotion else { return }
                // A long, unhurried cycle. Anything quicker reads as a
                // notification badge rather than a material.
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false).delay(0.4)) {
                    sweep = 2
                }
            }
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
    /// The free-trial line, when this subscriber can actually have one. Set
    /// in gold with a slow sheen — it is the single most persuasive thing on
    /// the screen and was previously buried in the same grey as the price.
    var trialHeadline: String? = nil
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text(title)
                            .font(Theme.Typography.headline)
                            .foregroundColor(GoldenPalette.primaryText)

                        // The trial sits on the title line, immediately after
                        // the plan name — the first thing read on the row
                        // rather than a footnote under it.
                        if let trialHeadline {
                            ShinyGoldText(trialHeadline)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(GoldenPalette.flameBottom.opacity(0.14))
                                )
                                .overlay(
                                    Capsule().strokeBorder(
                                        GoldenPalette.flameBottom.opacity(0.45), lineWidth: 0.8
                                    )
                                )
                                .fixedSize()
                        } else if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, Theme.Spacing.xxs)
                                .padding(.vertical, 3)
                                .background(GoldenPalette.flameBottom.opacity(0.15))
                                .foregroundColor(GoldenPalette.flameBottom)
                                .clipShape(Capsule())
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.caption)
                            .foregroundColor(GoldenPalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(Theme.Typography.title2)
                        .foregroundColor(GoldenPalette.primaryText)
                    Text(period)
                        .font(Theme.Typography.caption)
                        .foregroundColor(GoldenPalette.secondaryText)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs + 2)
            .background(
                RoundedRectangle(cornerRadius: GoldenPalette.cornerRadius, style: .continuous)
                    .fill(GoldenPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GoldenPalette.cornerRadius, style: .continuous)
                    .stroke(isSelected ? GoldenPalette.flameBottom : GoldenPalette.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Laurel Badge
/// A victory wreath with a line of text inside it — the two halves of SF
/// Symbols' laurel, mirrored around the label rather than a single glyph,
/// since there is no whole-wreath symbol.
struct LaurelBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 32, weight: .light))

            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize()

            Image(systemName: "laurel.trailing")
                .font(.system(size: 32, weight: .light))
        }
        .foregroundStyle(GoldenPalette.flameGradient)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Review Card
/// Five stars and one real review. Deliberately the same plain-row
/// language as everything else on the screen — a bordered card with a
/// quote, not a marketing testimonial block with a photo and a full name.
struct PaywallReviewCard: View {
    let review: AppStrings.Paywall.Review

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxs) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(GoldenPalette.flameGradient)
                }
            }

            Text(review.quote)
                .font(Theme.Typography.footnote)
                .foregroundColor(GoldenPalette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(review.attribution)")
                .font(.system(size: 11))
                .foregroundColor(GoldenPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: GoldenPalette.cornerRadius, style: .continuous)
                .fill(GoldenPalette.cardBackground.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GoldenPalette.cornerRadius, style: .continuous)
                .stroke(GoldenPalette.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Paywall Icon
/// The real Verg app icon — the purple mark, its own dark backdrop
/// contained within its rounded frame, so it reads as the one saturated
/// object in the light. Static: it's raster artwork, not a procedural
/// flame, so it doesn't animate here (contrast with the in-session candle).
struct PaywallIcon: View {
    var body: some View {
        Image("VergIcon")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .shadow(color: Theme.Colors.accent.opacity(0.22), radius: 14, x: 0, y: 4)
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
        .environmentObject(PurchaseService.shared)
}
