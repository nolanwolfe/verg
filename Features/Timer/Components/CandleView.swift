import SwiftUI

/// Animated candle view that burns down over time
struct CandleView: View {
    let progress: Double
    var isBurning: Bool = true

    // Flicker animation state
    @State private var flameOffset: CGFloat = 0
    @State private var flameScale: CGFloat = 1.0
    @State private var innerFlameOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.35

    // Burnout-only state
    @State private var burnoutAnimating: Bool = false
    @State private var emberOpacity: Double = 0.0

    private let candleWidth: CGFloat = 80
    private let maxCandleHeight: CGFloat = 200
    private let wickLength: CGFloat = 15

    private var candleHeight: CGFloat { maxCandleHeight * progress }
    private var wickHeight: CGFloat { max(8, wickLength * progress) }

    var body: some View {
        VStack(spacing: 0) {
            // Flame only shows while burning or during the burnout sequence
            if isBurning || burnoutAnimating {
                glowEffect
                flameView
                    .offset(y: 10)
            }
            wickView
                .offset(y: 5)
            candleBody
        }
        .task(id: isBurning) {
            if isBurning {
                // Reset in case a previous burnout left scale at 0
                flameScale = 1.0
                flameOffset = 0
                innerFlameOffset = 0
                glowOpacity = 0.35
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
        while !Task.isCancelled {
            let duration = Double.random(in: 0.08...0.18)
            withAnimation(.easeInOut(duration: duration)) {
                flameOffset = CGFloat.random(in: -2...2)
                flameScale = CGFloat.random(in: 0.93...1.07)
                innerFlameOffset = CGFloat.random(in: -1.5...1.5)
                glowOpacity = Double.random(in: 0.28...0.45)
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 0.75 * 1_000_000_000))
        }
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
        ZStack {
            // Outer flame
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.flameOuter, Theme.Colors.flameOuter.opacity(0.8)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 30, height: 50)
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
                .frame(width: 18, height: 35)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.candleWax, Theme.Colors.candleWaxDark, Theme.Colors.candleWax],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            RoundedRectangle(cornerRadius: 8)
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
                            colors: [Theme.Colors.candleWaxDark.opacity(0.3), Color.clear],
                            center: .center, startRadius: 5, endRadius: candleWidth / 2
                        )
                    )
                    .frame(width: candleWidth - 10, height: 20)
                    .offset(y: 5)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: candleHeight)
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
                        colors: [Color(hex: "FF4500"), Color(hex: "FFCC00")],
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
