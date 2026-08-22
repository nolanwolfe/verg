import SwiftUI
import UIKit

/// Full-screen timer view — candle burns down as time runs out
struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.dismiss) private var dismiss

    var onComplete: ((Session?) -> Void)?

    @State private var showControls: Bool = true
    @State private var hideTask: Task<Void, Never>?
    @State private var glowPulse: Double = 0.0
    @State private var completionFlash: Double = 0.0

    // Brightness (swipe up/down, no visual indicator)
    @State private var brightness: Double = 0.7
    @State private var savedSystemBrightness: CGFloat = UIScreen.main.brightness
    @State private var dragStartBrightness: Double = 0.7

    var body: some View {
        ZStack {
            Color(hex: "080400").ignoresSafeArea()

            ambientGlow

            // Candle — upper position matching Verg tab
            GeometryReader { geo in
                CandleView(
                    progress: viewModel.progress,
                    isBurning: viewModel.isRunning
                )
                .scaleEffect(1.9)
                .shadow(
                    color: Color(hex: "FF9500").opacity(0.5 * viewModel.progress + glowPulse * 0.08),
                    radius: 50, x: 0, y: 0
                )
                .position(x: geo.size.width / 2, y: geo.size.height * 0.40)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Controls: X + countdown (tap anywhere to toggle)
            if showControls {
                controlsOverlay
                    .transition(.opacity.animation(Theme.Animation.standard))
            }

            // Warm flash when candle extinguishes
            Color(hex: "FF6000")
                .opacity(completionFlash)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Coach mark
            if viewModel.showUploadPhotoNotice {
                CoachMarkNoticeView(
                    title: AppStrings.CoachMark.UploadPhoto.title,
                    message: AppStrings.CoachMark.UploadPhoto.body,
                    primaryButtonText: AppStrings.CoachMark.UploadPhoto.primaryButton,
                    tertiaryButtonText: AppStrings.CoachMark.UploadPhoto.tertiaryButton,
                    secondaryButtonText: AppStrings.CoachMark.UploadPhoto.secondaryButton,
                    onPrimaryTap: {
                        DispatchQueue.main.async { viewModel.onUploadPhotoTapped() }
                    },
                    onTertiaryTap: {
                        DispatchQueue.main.async { viewModel.onAddFiveMinutesTapped() }
                    },
                    onSecondaryTap: {
                        DispatchQueue.main.async { viewModel.onSkipPhotoTapped() }
                    }
                )
            }

            // Milestone celebration — above everything
            if let milestone = viewModel.celebratedMilestone {
                MilestoneCelebrationView(milestone: milestone) {
                    DispatchQueue.main.async { viewModel.dismissCelebration() }
                }
                .zIndex(2)
            }

            // Time Reclaimed reveal — the last thing shown before returning home
            if let moment = viewModel.timeReclaimedMoment {
                TimeReclaimedCardView(moment: moment) {
                    DispatchQueue.main.async { viewModel.dismissTimeReclaimed() }
                }
                .zIndex(3)
            }
        }
        // Tap toggles controls — must be on ZStack, not inner views
        .onChange(of: viewModel.isComplete) { _, complete in
            guard complete else { return }
            // Brief warm flash as candle extinguishes
            withAnimation(.easeOut(duration: 0.12)) { completionFlash = 0.28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeIn(duration: 0.9)) { completionFlash = 0.0 }
            }
        }
        .onTapGesture { toggleControls() }
        // Swipe brightness — simultaneous so tap still fires
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let delta = Double(-value.translation.height) / 300.0
                    brightness = max(0.05, min(1.0, dragStartBrightness + delta))
                    UIScreen.main.brightness = brightness
                }
                .onEnded { _ in
                    dragStartBrightness = brightness
                }
        )
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(
                duration: viewModel.totalDuration,
                activeDuration: viewModel.activeDuration,
                onPhotoSaved: { session in viewModel.onPhotoSaved(session) },
                onCancel: {
                    viewModel.showCamera = false
                    dismiss()
                    onComplete?(nil)
                }
            )
        }
        .onAppear {
            viewModel.onComplete = { session in dismiss(); onComplete?(session) }
            scheduleHide()
            startGlowPulse()
            savedSystemBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = brightness
            dragStartBrightness = brightness
            UIApplication.shared.isIdleTimerDisabled = true
            DispatchQueue.main.async {
                viewModel.startTimer()
            }
        }
        .onDisappear {
            viewModel.stopTimer()
            hideTask?.cancel()
            UIScreen.main.brightness = savedSystemBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .statusBar(hidden: true)
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        ZStack {
            // X button — top left
            VStack {
                HStack {
                    Button { viewModel.cancelSession() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "FF9500").opacity(0.5))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.top, Theme.Spacing.sm)
                Spacer()
            }

            // Countdown — floats above the candle, room to breathe
            GeometryReader { geo in
                Text(viewModel.formattedTime)
                    .font(Theme.Typography.timerDisplay)
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .shadow(color: Color(hex: "FF9500").opacity((0.5 + 0.3 * viewModel.progress) * (0.6 + glowPulse * 0.4)), radius: 14, x: 0, y: 0)
                    .shadow(color: Color(hex: "FFCC00").opacity(0.25 * viewModel.progress), radius: 5, x: 0, y: 0)
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.19)
            }
        }
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(hex: "FF7000").opacity((0.30 + glowPulse * 0.04) * viewModel.progress),
                    Color(hex: "FF5500").opacity((0.22 + glowPulse * 0.02) * viewModel.progress),
                    Color(hex: "FF3300").opacity(0.10 * viewModel.progress),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.clear, Color(hex: "FF6000").opacity(0.10 * viewModel.progress)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.8), value: viewModel.progress)
    }

    // MARK: - Helpers

    private func startGlowPulse() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            glowPulse = 1.0
        }
    }

    private func toggleControls() {
        withAnimation(Theme.Animation.standard) { showControls.toggle() }
        if showControls { scheduleHide() } else { hideTask?.cancel() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(Theme.Animation.slow) { showControls = false }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TimerView()
}
