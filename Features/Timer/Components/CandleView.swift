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
        let height = minCandleHeight + (maxCandleHeight - minCandleHeight) * progress
        return max(height, minCandleHeight)
    }

    private var wickHeight: CGFloat {
        wickLength * (0.5 + progress * 0.5)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Glow effect
            if isBurning {
                glowEffect
            }

            // Flame
            if isBurning {
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
            if isBurning {
                startFlameAnimation()
            }
        }
        .onChange(of: isBurning) { _, burning in
            if burning {
                startFlameAnimation()
            }
        }
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
                        colors: [
                            Theme.Colors.flameOuter,
                            Theme.Colors.flameOuter.opacity(0.8)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 30, height: 50)
                .scaleEffect(x: flameScale, y: flameScale * 1.1)
                .offset(x: flameOffset)

            // Inner flame
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.flameInner,
                            Theme.Colors.flameInner.opacity(0.9)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 18, height: 35)
                .scaleEffect(x: flameScale * 0.9, y: flameScale)
                .offset(x: innerFlameOffset, y: 5)

            // Core (white hot)
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.flameCore,
                            Theme.Colors.flameCore.opacity(0.8)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
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
            // Wick
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.Colors.wickColor)
                .frame(width: 3, height: wickHeight)

            // Burnt tip (only when burning)
            if isBurning {
                Circle()
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 5, height: 5)
                    .offset(y: -1)
            }
        }
    }

    // MARK: - Candle Body
    private var candleBody: some View {
        ZStack(alignment: .top) {
            // Main candle body
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.candleWax,
                            Theme.Colors.candleWaxDark,
                            Theme.Colors.candleWax
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            // Left highlight
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .center
                    )
                )
                .frame(width: candleWidth, height: candleHeight)

            // Wax drip effect
            if progress < 0.9 && isBurning {
                waxDrips
            }

            // Top melted wax pool
            if isBurning {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.candleWaxDark.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: candleWidth / 2
                        )
                    )
                    .frame(width: candleWidth - 10, height: 20)
                    .offset(y: 5)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: candleHeight)
    }

    // MARK: - Wax Drips
    private var waxDrips: some View {
        HStack(spacing: candleWidth / 4) {
            WaxDrip(height: 25 * (1 - progress))
                .offset(y: 10)

            WaxDrip(height: 15 * (1 - progress))
                .offset(y: 15)

            WaxDrip(height: 20 * (1 - progress))
                .offset(y: 8)
        }
        .offset(x: -5)
    }

    // MARK: - Animation
    private func startFlameAnimation() {
        // Flicker animation
        withAnimation(
            Animation.easeInOut(duration: 0.15)
                .repeatForever(autoreverses: true)
        ) {
            flameOffset = CGFloat.random(in: -2...2)
            flameScale = CGFloat.random(in: 0.95...1.05)
        }

        // Inner flame flicker (slightly different timing)
        withAnimation(
            Animation.easeInOut(duration: 0.12)
                .repeatForever(autoreverses: true)
        ) {
            innerFlameOffset = CGFloat.random(in: -1.5...1.5)
        }

        // Glow pulse
        withAnimation(
            Animation.easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
        ) {
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

        // Start at bottom center
        path.move(to: CGPoint(x: width / 2, y: height))

        // Left curve
        path.addQuadCurve(
            to: CGPoint(x: width * 0.1, y: height * 0.5),
            control: CGPoint(x: 0, y: height * 0.8)
        )

        // Top left curve to tip
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: 0),
            control: CGPoint(x: width * 0.2, y: height * 0.2)
        )

        // Top right curve from tip
        path.addQuadCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.5),
            control: CGPoint(x: width * 0.8, y: height * 0.2)
        )

        // Right curve back to bottom
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: height),
            control: CGPoint(x: width, y: height * 0.8)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Wax Drip
struct WaxDrip: View {
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Theme.Colors.candleWax,
                        Theme.Colors.candleWaxDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 6, height: max(height, 0))
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        VStack(spacing: 40) {
            CandleView(progress: 1.0, isBurning: true)
            CandleView(progress: 0.5, isBurning: true)
            CandleView(progress: 0.1, isBurning: true)
        }
    }
}
