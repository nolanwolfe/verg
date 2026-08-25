import SwiftUI
import UIKit

/// Full-screen timer view — candle burns down as time runs out
struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.dismiss) private var dismiss

    /// The prompt chosen on the Write screen, carried through to the saved
    /// page. Nil when the user chose no prompt.
    var prompt: String?
    var onComplete: ((Session?) -> Void)?

    @State private var showControls: Bool = true
    @State private var hideTask: Task<Void, Never>?
    @State private var glowPulse: Double = 0.0
    @State private var completionFlash: Double = 0.0
    @State private var showAmbiencePicker = false
    @State private var showPaywall = false

    private let gatingService = SessionGatingService.shared

    // Brightness (swipe up/down, no visual indicator)
    @Environment(\.colorScheme) private var colorScheme
    /// See VergFlameView: these opacities were tuned against near-black and
    /// turn the room orange when laid over paper at full strength.
    private var glowScale: Double { colorScheme == .dark ? 1.0 : 0.34 }
    @State private var brightness: Double = 0.7
    @State private var dragStartBrightness: Double = 0.7

    var body: some View {
        ZStack {
            // Same warm ground as the Verg tab: near-black by candlelight,
            // paper near a flame in the light theme.
            Theme.Colors.adaptive(light: "FBF3E6", dark: "080400").ignoresSafeArea()

            ambientGlow

            // Candle — smaller, more centered in the screen
            GeometryReader { geo in
                CandleView(
                    // Deliberately not `viewModel.isRunning`: CandleView drops
                    // its flame and glow out of the layout entirely when not
                    // burning, which shrinks its rendered height — and since
                    // it's centred here with `.position()`, that made the whole
                    // candle jump on pause. Pausing isn't blowing the candle
                    // out; only real completion is.
                    progress: viewModel.progress,
                    isBurning: !viewModel.isComplete
                )
                .scaleEffect(1.3)
                .shadow(
                    color: Theme.Colors.flameOuter.opacity(0.5 * viewModel.progress + glowPulse * 0.08),
                    radius: 50, x: 0, y: 0
                )
                .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
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

            // Weekly-goal milestone celebration — queued behind the page
            // milestone above, shown next if both crossed on the same save
            if let goalMilestone = viewModel.celebratedGoalMilestone {
                MilestoneCelebrationView(goalMilestone: goalMilestone) {
                    DispatchQueue.main.async { viewModel.dismissGoalCelebration() }
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

            // A crossed terrace — quiet, non-blocking, never a takeover
            if let terraceMessage = viewModel.terraceMessage {
                VStack {
                    Text(terraceMessage)
                        .font(Theme.Typography.subheadline.italic())
                        .foregroundColor(Theme.Colors.primaryText.opacity(0.85))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Capsule().fill(Theme.Colors.adaptive(light: "FFFFFFA6", dark: "00000066")))
                        .padding(.top, Theme.Spacing.xxl)
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(4)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        withAnimation(Theme.Animation.slow) { viewModel.terraceMessage = nil }
                    }
                }
                .allowsHitTesting(false)
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
                    BrightnessService.shared.set(brightness)
                }
                .onEnded { _ in
                    dragStartBrightness = brightness
                }
        )
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(
                duration: viewModel.totalDuration,
                activeDuration: viewModel.activeDuration,
                prompt: prompt,
                onPhotoSaved: { session in viewModel.onPhotoSaved(session) },
                onCancel: {
                    viewModel.showCamera = false
                    dismiss()
                    onComplete?(nil)
                }
            )
        }
        .sheet(isPresented: $showAmbiencePicker) {
            ambiencePickerSheet
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(PurchaseService.shared)
        }
        .onAppear {
            viewModel.onComplete = { session in dismiss(); onComplete?(session) }
            scheduleHide()
            startGlowPulse()
            brightness = BrightnessService.shared.levelOnAppear(default: 0.7)
            BrightnessService.shared.take(brightness)
            dragStartBrightness = brightness
            UIApplication.shared.isIdleTimerDisabled = true
            DispatchQueue.main.async {
                viewModel.startTimer()
            }
        }
        .onDisappear {
            viewModel.stopTimer()
            hideTask?.cancel()
            // Brightness deliberately persists — see BrightnessService.
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .statusBar(hidden: true)

    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        ZStack {
            // X button — top left, small and white
            VStack {
                HStack {
                    Button { viewModel.cancelSession() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.top, Theme.Spacing.sm)

                // The script, in with the chrome. It first lived outside
                // this overlay so it would stay put while the controls came
                // and went; the owner wants it to behave like everything
                // else on this screen, so it now fades with the countdown
                // and the bottom row. Same colour as the countdown, too —
                // it is one of the readouts, not a watermark.
                if let prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xxs)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("timer.script")
                }

                Spacer()
            }

            // Countdown — floats right above the candle
            GeometryReader { geo in
                Text(viewModel.formattedTime)
                    .font(Theme.Typography.timerDisplay)
                    .foregroundColor(Theme.Colors.primaryText)
                    .monospacedDigit()
                    .shadow(color: Theme.Colors.flameOuter.opacity((0.5 + 0.3 * viewModel.progress) * (0.6 + glowPulse * 0.4)), radius: 14, x: 0, y: 0)
                    .shadow(color: Theme.Colors.flameInner.opacity(0.25 * viewModel.progress), radius: 5, x: 0, y: 0)
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.30)
            }

            // Bottom controls — pause/resume, plus sound choice and mute
            // (Pro features; tapping either while free opens the paywall)
            VStack {
                Spacer()
                bottomControls
                    .padding(.bottom, Theme.Spacing.xxl)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: Theme.Spacing.xl) {
            Button(action: handleAmbienceTap) {
                Image(systemName: "music.note")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryText.opacity(gatingService.isPremium ? 1 : 0.4))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.Colors.adaptive(light: "FFFFFFA6", dark: "00000066")))
            }

            Button {
                viewModel.isRunning ? viewModel.pauseTimer() : viewModel.resumeTimer()
            } label: {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Theme.Colors.adaptive(light: "FFFFFFA6", dark: "00000066")))
            }

            Button(action: handleMuteTap) {
                Image(systemName: viewModel.ambientSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryText.opacity(gatingService.isPremium ? 1 : 0.4))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.Colors.adaptive(light: "FFFFFFA6", dark: "00000066")))
            }
        }
        .buttonStyle(.plain)
    }

    private func handleAmbienceTap() {
        if gatingService.isPremium {
            AudioService.shared.playImpact(.light)
            showAmbiencePicker = true
        } else {
            showPaywall = true
        }
    }

    private func handleMuteTap() {
        if gatingService.isPremium {
            viewModel.toggleAmbienceMuted()
        } else {
            showPaywall = true
        }
    }

    // MARK: - Ambience Picker Sheet
    private var ambiencePickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.sm) {
                    Button {
                        viewModel.setAmbienceEnabled(false)
                    } label: {
                        ambienceRow(icon: "speaker.slash", iconColor: Theme.Colors.secondaryText, title: "Off", isSelected: !viewModel.ambientSoundEnabled)
                    }

                    ForEach(AudioService.AmbientSound.allCases) { sound in
                        Button {
                            viewModel.selectAmbientSound(sound)
                        } label: {
                            ambienceRow(
                                icon: sound.icon,
                                iconColor: Theme.Colors.flameOuter,
                                title: sound.displayName,
                                isSelected: viewModel.ambientSoundEnabled && viewModel.ambientSoundID == sound.rawValue
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Ambience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showAmbiencePicker = false }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func ambienceRow(icon: String, iconColor: Color, title: String, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.small)
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(hex: "FF7000").opacity((0.30 + glowPulse * 0.04) * viewModel.progress * glowScale),
                    Color(hex: "FF5500").opacity((0.22 + glowPulse * 0.02) * viewModel.progress * glowScale),
                    Color(hex: "FF3300").opacity(0.10 * viewModel.progress * glowScale),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.clear, Color(hex: "FF6000").opacity(0.10 * viewModel.progress * glowScale)],
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
