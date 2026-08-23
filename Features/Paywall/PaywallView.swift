import SwiftUI

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
    static let background = Color(hex: "FFFDF9")       // paper, near-white
    static let crown = Color(hex: "FFFFFF")            // the break of light, top of frame
    static let haloGold = Color(hex: "FFDE9B")         // the gold in the opening
    static let summitGlow = Color(hex: "FFF4E0")
    static let cardBackground = Color(hex: "FBF7EF")
    static let cardBorder = Color(hex: "EDE5D6")
    static let primaryText = Color(hex: "1E1B14")
    static let secondaryText = Color(hex: "746C5E")     // warm gray, not cool
    static let waxColor = Color(hex: "FFF8E7")
    static let flameTop = Color(hex: "B08A52")          // ember
    static let flameBottom = Color(hex: "A44A32")       // ember
    static let flameGradient = LinearGradient(colors: [flameTop, flameBottom], startPoint: .top, endPoint: .bottom)
    /// Deeper than `flameGradient` so white text clears contrast on it —
    /// the pale ember yellow alone is far too light to sit white on.
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "B08A52"), Color(hex: "8E6B3F")],
        startPoint: .top,
        endPoint: .bottom
    )
    static let cornerRadius: CGFloat = 12
}

/// The actual paywall content.
struct NativePaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.height < 600
            let inlineReviews = geo.size.height >= 700

            ZStack {
                GoldenPalette.background.ignoresSafeArea()
                heavenLight

                // The pitch occupies exactly one screen — `minHeight` pins it
                // to the viewport. The scroll exists only to reach the laurel
                // below, which is what the chevron above the plans points at.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        mainColumn(isCompact: isCompact, inlineReviews: inlineReviews)
                            .frame(minHeight: geo.size.height)

                        belowFold(includingReviews: !inlineReviews)
                    }
                }

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

    // MARK: - Main Column (the one-screen pitch)
    private func mainColumn(isCompact: Bool, inlineReviews: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.xs) {
                header
                heroFeatureCards
            }
            .padding(.top, isCompact ? Theme.Spacing.sm : Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.sm)

            if inlineReviews {
                reviewStack
                Spacer(minLength: Theme.Spacing.sm)
            }

            VStack(spacing: Theme.Spacing.sm) {
                // The laurel sits between the reviews and Yearly rather than
                // below the fold — it's the mark, not a footnote.
                LaurelBadge(text: AppStrings.Paywall.laurelBadge)

                VStack(spacing: Theme.Spacing.xs) {
                    planSelection
                    ctaSection
                    footer
                }
            }
            .padding(.bottom, Theme.Spacing.xxs)
        }
        // Tighter gutters, and a ceiling so the column stays a narrow shaft
        // of content on larger phones rather than stretching edge to edge.
        .padding(.horizontal, Theme.Spacing.md)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    /// The two review cards and, directly beneath them, the three words
    /// that keep them honest. These travel together — see the note on
    /// `AppStrings.Paywall.reviews`; the cards must never render without
    /// this line.
    private var reviewStack: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            ForEach(Array(AppStrings.Paywall.reviews.enumerated()), id: \.offset) { _, review in
                PaywallReviewCard(review: review)
            }

            Text(AppStrings.Paywall.reviewsAreFictionNote)
                .font(.system(size: 10))
                .foregroundColor(GoldenPalette.secondaryText.opacity(0.7))
        }
    }

    // MARK: - Below the Fold
    /// Only used on screens too short to carry the reviews inline; they're
    /// reached by scrolling. Empty otherwise, so the page simply doesn't
    /// scroll on a large phone.
    @ViewBuilder
    private func belowFold(includingReviews: Bool) -> some View {
        if includingReviews {
            reviewStack
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
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
                        .foregroundColor(GoldenPalette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(GoldenPalette.cardBackground)
                        .overlay(Circle().stroke(GoldenPalette.cardBorder, lineWidth: 1))
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
                .font(Theme.Typography.title2)
                .foregroundColor(GoldenPalette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(viewModel.subtitleText)
                .font(Theme.Typography.footnote)
                .foregroundColor(GoldenPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                // Without this the line gets offered a single-line width by
                // the surrounding stack and truncates mid-sentence instead
                // of wrapping to the second line it's allowed.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xs)
        }
    }

    // MARK: - Hero Features (the actual sell — archive + stats)
    /// Quiet rows, not boxed cards: the paywall borrows the app's own
    /// plain-list language rather than a marketing-page card grid.
    private var heroFeatureCards: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(viewModel.heroFeatures) { feature in
                HStack(spacing: Theme.Spacing.xs) {
                    Group {
                        if feature.usesCandleMark {
                            CandleFlameIcon(size: 12)
                        } else {
                            Image(systemName: feature.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(GoldenPalette.flameGradient)
                        }
                    }
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
                            .foregroundColor(GoldenPalette.primaryText)

                        if let badge {
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
                .font(.system(size: 40, weight: .light))

            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize()

            Image(systemName: "laurel.trailing")
                .font(.system(size: 40, weight: .light))
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
