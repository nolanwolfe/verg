import SwiftUI
import UIKit

/// Verg — candlelight mode for journaling in the dark
struct VergFlameView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var brightness: Double = 0.65
    @State private var glowPulse: Double = 0.0
    @State private var showControls: Bool = true
    @State private var hideTask: Task<Void, Never>?
    @State private var phraseIndex: Int = 0

    private let phrases: [String] = [
        "candlelight",
        "on the verg of greatness",
        "believe in yourself",
        "write",
        "the page is waiting",
        "clarity lives in stillness",
        "your story matters"
    ]

    // Swipe gesture tracking
    @State private var dragStartBrightness: Double = 0.65

    var body: some View {
        ZStack {
            // Deep warm-black base
            // Warm to the bone in both: near-black by candlelight, and the
            // colour of paper held near a flame in the light theme. Not
            // Theme.Colors.background — this room is warmer than the rest of
            // the app on purpose.
            Theme.Colors.adaptive(light: "FBF3E6", dark: "080400").ignoresSafeArea()

            // Ambient radial glow — the room lit by flame
            ambientBackground

            // The candle
            candleCenter

            // Controls (tap to toggle, auto-hide)
            if showControls {
                controls
                    .transition(.opacity.animation(Theme.Animation.standard))
            }

}
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let delta = Double(-value.translation.height) / 300.0
                    brightness = max(0.1, min(1.0, dragStartBrightness + delta))
                }
                .onEnded { _ in
                    dragStartBrightness = brightness
                }
        )
        .onTapGesture { toggleControls() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            // Adopt whatever the app is already holding, so arriving here
            // from another screen does not jump the brightness.
            brightness = BrightnessService.shared.levelOnAppear(default: 0.65)
            BrightnessService.shared.take(brightness)
            dragStartBrightness = brightness
            startGlowPulse()
            scheduleHide()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            // Deliberately does not restore: brightness belongs to the app
            // until the app itself goes away. Restoring here is what made
            // every tab change flash.
            hideTask?.cancel()
        }
        .onChange(of: brightness) { _, value in
            BrightnessService.shared.set(value)
        }
    }

    // MARK: - Ambient Background

    /// Glow strength. The opacities below were tuned against near-black,
    /// where light has to be strong to register at all. Laid over paper at
    /// the same values the room turns orange — light *adds*, and there is
    /// already a lit ground under it. A third of the strength reads as the
    /// same flame in a room that happens to have daylight in it.
    private var glowScale: Double { colorScheme == .dark ? 1.0 : 0.34 }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(hex: "FF7000").opacity((lerp(0.30, 0.55, brightness) + glowPulse * 0.04) * glowScale),
                    Color(hex: "FF5500").opacity((lerp(0.18, 0.35, brightness) + glowPulse * 0.02) * glowScale),
                    Color(hex: "FF3300").opacity(lerp(0.06, 0.14, brightness) * glowScale),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.46),
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.clear, Color(hex: "FF6000").opacity(lerp(0.04, 0.12, brightness) * glowScale)],
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
                        color: Theme.Colors.flameOuter.opacity(0.5 * brightness + glowPulse * 0.08),
                        radius: 50, x: 0, y: 0
                    )
                Spacer()
                Spacer().frame(height: 120)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            Text(phrases[phraseIndex])
                .font(.system(size: 13, weight: .ultraLight, design: .serif))
                // Ember on black, but that same orange laid over a lit
                // orange glow is invisible. On paper the word takes the
                // room's own ink instead.
                .foregroundColor(
                    colorScheme == .dark
                        ? Theme.Colors.flameOuter.opacity(0.45)
                        : Color(hex: "8A6A3A").opacity(0.75)
                )
                .tracking(5)
                .multilineTextAlignment(.center)
                .padding(.top, 64)
                .padding(.horizontal, 32)
                .id(phraseIndex)
                .transition(.opacity)

            Spacer()
        }
    }


    // MARK: - Animations

    private func startGlowPulse() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            glowPulse = 1.0
        }
    }

    // MARK: - Visibility Helpers

    private func toggleControls() {
        if showControls {
            // Already visible — advance to next phrase then hide
            withAnimation(Theme.Animation.standard) {
                phraseIndex = (phraseIndex + 1) % phrases.count
            }
            scheduleHide()
        } else {
            withAnimation(Theme.Animation.standard) { showControls = true }
            scheduleHide()
        }
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

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

#Preview {
    VergFlameView()
}
