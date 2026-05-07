import SwiftUI
import UIKit

/// Full-screen candlelight ambient mode — warm light for journaling in the dark
struct CandleAmbientView: View {

    @State private var brightness: Double = 0.65
    @State private var savedSystemBrightness: CGFloat = UIScreen.main.brightness
    @State private var glowPulse: Double = 0.0
    @State private var showControls: Bool = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Deep warm-black base
            Color(hex: "080400").ignoresSafeArea()

            // Ambient radial glow — the room lit by flame
            ambientBackground

            // The candle itself
            candleCenter

            // Tap-to-reveal controls
            if showControls {
                controls
                    .transition(.opacity.animation(Theme.Animation.standard))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            savedSystemBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = brightness
            startGlowPulse()
            scheduleHide()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            UIScreen.main.brightness = savedSystemBrightness
            hideTask?.cancel()
        }
        .onChange(of: brightness) { _, value in
            UIScreen.main.brightness = value
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            // Primary candle-glow sphere — wide and soft
            RadialGradient(
                colors: [
                    Color(hex: "FF7000").opacity(lerp(0.30, 0.55, brightness) + glowPulse * 0.04),
                    Color(hex: "FF5500").opacity(lerp(0.18, 0.35, brightness) + glowPulse * 0.02),
                    Color(hex: "FF3300").opacity(lerp(0.06, 0.14, brightness)),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            // Warm floor blush at the very bottom
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(hex: "FF6000").opacity(lerp(0.04, 0.12, brightness))
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Candle Center

    private var candleCenter: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                CandleView(progress: 1.0, isBurning: true)
                    .scaleEffect(1.9)
                    .shadow(
                        color: Color(hex: "FF9500").opacity(0.5 * brightness + glowPulse * 0.08),
                        radius: 50, x: 0, y: 0
                    )
                Spacer()
                // Push up from bottom to leave room for tab bar + controls
                Spacer().frame(height: 120)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Controls Overlay

    private var controls: some View {
        VStack {
            // Label
            Text("candlelight")
                .font(.system(size: 13, weight: .ultraLight, design: .serif))
                .foregroundColor(Color(hex: "FF9500").opacity(0.45))
                .tracking(5)
                .padding(.top, 64)

            Spacer()

            // Brightness bar
            brightnessBar
                .padding(.bottom, 24)
        }
    }

    private var brightnessBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: "sun.min")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color(hex: "FF9500").opacity(0.5))

                Slider(value: $brightness, in: 0.1...1.0)
                    .tint(Color(hex: "FFAA00"))
                    .frame(maxWidth: 220)

                Image(systemName: "sun.max")
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(Color(hex: "FF9500").opacity(0.8))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(hex: "FF9500").opacity(0.15), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Helpers

    private func toggleControls() {
        withAnimation(Theme.Animation.standard) {
            showControls.toggle()
        }
        if showControls { scheduleHide() }
        else { hideTask?.cancel() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(Theme.Animation.slow) { showControls = false }
            }
        }
    }

    private func startGlowPulse() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            glowPulse = 1.0
        }
    }

    /// Linear interpolation
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

// MARK: - Preview

#Preview {
    CandleAmbientView()
}
