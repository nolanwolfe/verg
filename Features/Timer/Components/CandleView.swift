import SwiftUI

/// Animated candle view that burns down over time
struct CandleView: View {
    /// Progress from 1.0 (full) to 0.0 (empty)
    let progress: Double

    /// Whether the candle should be burning
    var isBurning: Bool = true

    // MARK: - Animation State
    @State private var flameOffset: CGFloat = 0
    @State private var flameScale: CGFloat = 1.0
    @State private var innerFlameOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.3

    // MARK: - Constants
    private let candleWidth: CGFloat = 80
    private let maxCandleHeight: CGFloat = 200
    private let minCandleHeight: CGFloat = 30
    private let wickLength: CGFloat = 15

    // MARK: - Computed Properties
    private var candleHeight: CGFloat {
        max(minCandleHeight, minCandleHeight + (maxCandleHeight - minCandleHeight) * progress)
    }

    private var wickHeight: CGFloat {
        wickLength * (0.5 + progress * 0.5)
    }

    // Flame fully scales and fades to zero as candle burns out
    private var flameProgress: Double { progress }

    var body: some View {
        VStack(spacing: 0) {
            // Glow effect
            if isBurning {
                glowEffect
            }

            // Flame — fully gone at progress 0
            if isBurning && progress > 0.01 {
                flameView
                    .offset(y: 10)
            }

            // Wick
            wickView
                .offset(y: 5)

            // Candle body
            candleBody
        }
        .onAppear {
            if isBurning { startFlameAnimation() }
        }
        .onChange(of: isBurning) { _, burning in
            if burning { startFlameAnimation() }
        }
    }

    // MARK: - Glow Effect
    private var glowEffect: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Theme.Colors.flameOuter.opacity(glowOpacity * progress),
                        Theme.Colors.flameOuter.opacity(glowOpacity * progress * 0.5),
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
        let fp = max(0.01, flameProgress)
        return ZStack {
            // Outer flame
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.flameOuter, Theme.Colors.flameOuter.opacity(0.8)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 30 * fp, height: 50 * fp)
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
                .frame(width: 18 * fp, height: 35 * fp)
                .scaleEffect(x: flameScale * 0.9, y: flameScale)
                .offset(x: innerFlameOffset, y: 5 * fp)

            // Core (white hot)
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.flameCore, Theme.Colors.flameCore.opacity(0.8)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .frame(width: 8 * fp, height: 18 * fp)
                .offset(y: 12 * fp)
        }
        .opacity(fp)
        .shadow(color: Theme.Colors.flameOuter.opacity(0.8 * fp), radius: 15, x: 0, y: 0)
    }

    // MARK: - Wick View
    private var wickView: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.Colors.wickColor)
                .frame(width: 3, height: wickHeight)

            if isBurning && progress > 0.01 {
                Circle()
                    .fill(Color.orange.opacity(0.8 * progress))
                    .frame(width: 5, height: 5)
                    .offset(y: -1)
            }
        }
    }

    // MARK: - Candle Body
    private var candleBody: some View {
        ZStack(alignment: .top) {
            // Main wax body
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.candleWax, Theme.Colors.candleWaxDark, Theme.Colors.candleWax],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            // Left highlight
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .leading, endPoint: .center
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            // Melted wax pool at top
            if isBurning {
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

    // MARK: - Animation
    private func startFlameAnimation() {
        withAnimation(Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
            flameOffset = CGFloat.random(in: -2...2)
            flameScale = CGFloat.random(in: 0.95...1.05)
        }
        withAnimation(Animation.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
            innerFlameOffset = CGFloat.random(in: -1.5...1.5)
        }
        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            glowOpacity = 0.4
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

// MARK: - Preview
#Preview {
    ZStack {
        Color(hex: "080400").ignoresSafeArea()
        VStack(spacing: 40) {
            CandleView(progress: 1.0, isBurning: true)
            CandleView(progress: 0.5, isBurning: true)
            CandleView(progress: 0.1, isBurning: true)
        }
    }
}
