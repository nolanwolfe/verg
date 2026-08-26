import SwiftUI

/// Animated candle view that burns down over time.
///
/// `daysLit` is a second, independent dimension from `progress` — progress
/// is the in-session burn-down (resets every session), daysLit is how much
/// the candle has accumulated over time (resets only when a volume is
/// bound, a feature not yet built). A candle at day 80 still burns down
/// normally within a session; it just starts from a shorter, more-melted
/// resting height than a fresh candle would.
struct CandleView: View {
    let progress: Double
    var isBurning: Bool = true
    var daysLit: Int = 0

    // Flicker animation state
    @State private var flameOffset: CGFloat = 0
    @State private var flameScale: CGFloat = 1.0
    @State private var innerFlameOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.35

    // Burnout-only state
    @State private var burnoutAnimating: Bool = false
    @State private var emberOpacity: Double = 0.0

    /// Tracks the prior `isBurning` value so a false→true transition can be
    /// told apart from the view's very first appearance already lit — only
    /// the former is a "relight" (the candle was seen out, then caught
    /// again) and gets the catching-flame animation below.
    @State private var previousIsBurning: Bool?

    /// What the candle actually draws, top of glow to bottom of wax:
    /// 160 glow + 50 flame + 15 wick + 200 wax at its tallest.
    ///
    /// Published because `.frame(height:)` on this view changes only what it
    /// *claims* — the internals are fixed sizes and overflow a smaller box
    /// rather than shrinking into it. Anything laying the candle out next to
    /// other content has to scale it against this, not frame it.
    static let intrinsicHeight: CGFloat = 425

    private let candleWidth: CGFloat = 80
    private let wickLength: CGFloat = 15

    private var daysLitState: CandleDaysLitState { .forDaysLit(daysLit) }
    private var maxCandleHeight: CGFloat { daysLitState.maxHeight }
    private var candleHeight: CGFloat { maxCandleHeight * progress }
    private var wickHeight: CGFloat { max(8, wickLength * progress) }

    /// Glow + flame are only *visible* while burning or mid-burnout — but
    /// they always stay in the layout. Removing them from the VStack
    /// entirely dropped ~200pt of height and, under a top-aligned frame
    /// (Home screen), snapped the wick and wax visibly upward whenever the
    /// candle went unlit. Opacity keeps their footprint reserved so the
    /// candle body never moves.
    private var showFlame: Bool { isBurning || burnoutAnimating }

    var body: some View {
        VStack(spacing: 0) {
            glowEffect
                .opacity(showFlame ? 1 : 0)
            flameView
                .offset(y: 10)
                .opacity(showFlame ? 1 : 0)
            wickView
                .offset(y: 5)
            candleBody
        }
        .task(id: isBurning) {
            let wasBurning = previousIsBurning
            previousIsBurning = isBurning
            if isBurning {
                if wasBurning == false {
                    // Seen unlit before, now lit again: catch the flame
                    // rather than just popping it back in.
                    await runRelightSequence()
                } else {
                    // Reset in case a previous burnout left scale at 0
                    flameScale = 1.0
                    flameOffset = 0
                    innerFlameOffset = 0
                    glowOpacity = 0.35
                }
                await runFlickerLoop()
            } else if progress <= 0.02 {
                burnoutAnimating = true
                await runBurnoutSequence()
                burnoutAnimating = false
            }
        }
    }

    // MARK: - Flicker Loop

    @MainActor
    private func runFlickerLoop() async {
        // A flame that's been burning longer (higher days-lit state)
        // flickers less — steadier, not more energetic.
        let steadiness = daysLitState.jitterMultiplier
        while !Task.isCancelled {
            let duration = Double.random(in: 0.08...0.18)
            withAnimation(.easeInOut(duration: duration)) {
                flameOffset = CGFloat.random(in: -2...2) * steadiness
                flameScale = 1.0 + (CGFloat.random(in: -0.07...0.07) * steadiness)
                innerFlameOffset = CGFloat.random(in: -1.5...1.5) * steadiness
                glowOpacity = Double.random(in: 0.28...0.45)
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 0.75 * 1_000_000_000))
        }
    }

    // MARK: - Relight Sequence

    /// The inverse of the burnout sequence: a small flame catches, sputters
    /// unsteadily for a moment, then settles to full size before the
    /// ordinary flicker loop takes over.
    @MainActor
    private func runRelightSequence() async {
        flameScale = 0.001
        glowOpacity = 0
        flameOffset = 0
        innerFlameOffset = 0

        // Catch: a small, dim flame appears
        withAnimation(.easeOut(duration: 0.15)) {
            flameScale = 0.4
            glowOpacity = 0.15
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard !Task.isCancelled else { return }

        // Sputter: unsteady while it takes hold
        for _ in 0..<4 {
            withAnimation(.easeInOut(duration: 0.09)) {
                flameScale = CGFloat.random(in: 0.3...0.9)
                flameOffset = CGFloat.random(in: -3...3)
                glowOpacity = Double.random(in: 0.15...0.35)
            }
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }
        }

        // Settle to a steady full flame
        withAnimation(.easeOut(duration: 0.25)) {
            flameScale = 1.0
            flameOffset = 0
            innerFlameOffset = 0
            glowOpacity = 0.35
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
    }

    // MARK: - Burnout Sequence

    @MainActor
    private func runBurnoutSequence() async {
        // Rapid stutter for ~0.5s
        let end = Date().addingTimeInterval(0.5)
        while Date() < end && !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.04)) {
                flameOffset = CGFloat.random(in: -5...5)
                flameScale = CGFloat.random(in: 0.55...1.3)
                innerFlameOffset = CGFloat.random(in: -3...3)
                glowOpacity = Double.random(in: 0.1...0.7)
            }
            try? await Task.sleep(nanoseconds: 45_000_000)
        }
        guard !Task.isCancelled else { return }

        // Collapse flame to nothing
        withAnimation(.easeIn(duration: 0.25)) {
            flameScale = 0.001
            glowOpacity = 0
        }
        try? await Task.sleep(nanoseconds: 260_000_000)
        burnoutAnimating = false

        // Ember: brief orange glow on wick tip
        withAnimation(.easeIn(duration: 0.1)) { emberOpacity = 1.0 }
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.easeOut(duration: 2.0)) { emberOpacity = 0.0 }
    }

    // MARK: - Glow Effect

    private var glowEffect: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Theme.Colors.flameOuter.opacity(glowOpacity),
                        Theme.Colors.flameOuter.opacity(glowOpacity * 0.5),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 80
                )
            )
            .frame(width: 160, height: 160)
            .offset(y: 60)
    }

    // MARK: - Flame View

    private var flameView: some View {
        let flameGrowth = daysLitState.flameSizeMultiplier
        return ZStack {
            // Outer flame
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [daysLitState.flameOuterColor, daysLitState.flameOuterColor.opacity(0.8)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 30 * flameGrowth, height: 50 * flameGrowth)
                .scaleEffect(x: flameScale, y: flameScale * 1.1)
                .offset(x: flameOffset)

            // Inner flame
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.flameInner, Theme.Colors.flameInner.opacity(0.9)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 18 * flameGrowth, height: 35 * flameGrowth)
                .scaleEffect(x: flameScale * 0.9, y: flameScale)
                .offset(x: innerFlameOffset, y: 5)

            // Core (white-hot)
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.flameCore, Theme.Colors.flameCore.opacity(0.8)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 8, height: 18)
                .offset(y: 12)
        }
        .shadow(color: Theme.Colors.flameOuter.opacity(0.8), radius: 15, x: 0, y: 0)
    }

    // MARK: - Wick View

    private var wickView: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.Colors.wickColor)
                .frame(width: 3, height: wickHeight)

            if isBurning && progress > 0.02 {
                Circle()
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 5, height: 5)
                    .offset(y: -1)
            }

            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
                .shadow(color: Color.orange.opacity(0.8), radius: 6)
                .opacity(emberOpacity)
                .offset(y: -1)
        }
    }

    // MARK: - Candle Body

    private var candleBody: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [daysLitState.waxColor, daysLitState.waxColorDark, daysLitState.waxColor],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .leading, endPoint: .center
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            if isBurning && progress > 0 {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [daysLitState.waxColorDark.opacity(0.3), Color.clear],
                            center: .center, startRadius: 5, endRadius: candleWidth / 2
                        )
                    )
                    .frame(width: candleWidth - 10, height: 20)
                    .offset(y: 5)
            }

            // Melted wax pooled at the base — grows with days-lit state,
            // never with in-session progress.
            if daysLitState.poolWidth > 0 {
                waxPool
                    .offset(y: candleHeight - 4)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: candleHeight)
    }

    private var waxPool: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [daysLitState.waxColor, daysLitState.waxColorDark],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: candleWidth + daysLitState.poolWidth, height: daysLitState.poolHeight)
    }
}

// MARK: - Candle Days-Lit Visual State

/// How the candle's appearance carries the sense of accumulation — the
/// object changes instead of a tier label being shown. Four discrete
/// states, not a continuous simulation (same idea as an app icon having a
/// handful of fixed looks). A fifth "post-volume, reset with a marker"
/// state is intentionally not modeled yet — binding isn't built, so a
/// candle past 150 days just holds at the richest state rather than
/// resetting.
enum CandleDaysLitState: Equatable {
    case fresh        // 0–6: a fresh candle, full height, plain wax, small flame
    case settling     // 7–29: wax has begun to melt down one side, flame slightly steadier/larger
    case established  // 30–74: noticeably shorter, more wax pooled, warmer/richer flame
    case deep         // 75+: low, wax pooled deep, flame at its fullest and steadiest

    static func forDaysLit(_ daysLit: Int) -> CandleDaysLitState {
        switch daysLit {
        case ..<7: return .fresh
        case 7..<30: return .settling
        case 30..<75: return .established
        default: return .deep
        }
    }

    var maxHeight: CGFloat {
        switch self {
        case .fresh: return 200
        case .settling: return 186
        case .established: return 168
        case .deep: return 150
        }
    }

    var poolWidth: CGFloat {
        switch self {
        case .fresh: return 0
        case .settling: return 8
        case .established: return 16
        case .deep: return 24
        }
    }

    var poolHeight: CGFloat {
        switch self {
        case .fresh: return 0
        case .settling: return 7
        case .established: return 11
        case .deep: return 15
        }
    }

    var waxColor: Color {
        switch self {
        case .fresh: return Theme.Colors.candleWax
        case .settling: return Theme.Colors.candleWax
        case .established: return Color(hex: "F5E6C8")
        case .deep: return Color(hex: "F0DBA8")
        }
    }

    var waxColorDark: Color {
        switch self {
        case .fresh: return Theme.Colors.candleWaxDark
        case .settling: return Theme.Colors.candleWaxDark
        case .established: return Color(hex: "D8B888")
        case .deep: return Color(hex: "C9A268")
        }
    }

    /// Flame size grows slightly with days lit — "slightly steadier/
    /// larger" at settling, "fullest" at deep.
    var flameSizeMultiplier: CGFloat {
        switch self {
        case .fresh: return 1.0
        case .settling: return 1.06
        case .established: return 1.1
        case .deep: return 1.16
        }
    }

    /// Multiplies the flicker loop's random jitter — lower means steadier.
    var jitterMultiplier: CGFloat {
        switch self {
        case .fresh: return 1.0
        case .settling: return 0.85
        case .established: return 0.65
        case .deep: return 0.5
        }
    }

    var flameOuterColor: Color {
        switch self {
        case .fresh, .settling: return Theme.Colors.flameOuter
        case .established: return Color(hex: "FF8000")
        case .deep: return Color(hex: "FF7000")
        }
    }
}

// MARK: - Flame Shape

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        path.move(to: CGPoint(x: width / 2, y: height))
        path.addQuadCurve(to: CGPoint(x: width * 0.1, y: height * 0.5), control: CGPoint(x: 0, y: height * 0.8))
        path.addQuadCurve(to: CGPoint(x: width / 2, y: 0), control: CGPoint(x: width * 0.2, y: height * 0.2))
        path.addQuadCurve(to: CGPoint(x: width * 0.9, y: height * 0.5), control: CGPoint(x: width * 0.8, y: height * 0.2))
        path.addQuadCurve(to: CGPoint(x: width / 2, y: height), control: CGPoint(x: width, y: height * 0.8))
        path.closeSubpath()
        return path
    }
}

// MARK: - Candle Flame Icon

/// Small static flame in the app's candle-flame visual language.
/// Replaces the generic fire emoji in days-lit displays.
struct CandleFlameIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FF4500"), Theme.Colors.flameInner],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: size, height: size * 1.4)

            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFE000"), Color.white.opacity(0.9)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: size * 0.5, height: size * 0.8)
                .offset(y: size * 0.15)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: "080400").ignoresSafeArea()
        VStack(spacing: 40) {
            CandleView(progress: 1.0, isBurning: true)
            CandleView(progress: 0.5, isBurning: true)
            CandleView(progress: 0.1, isBurning: true)
            CandleFlameIcon()
        }
    }
}
