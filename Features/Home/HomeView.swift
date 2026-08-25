import SwiftUI
import UIKit

/// Home screen with candle and begin writing button
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var showTimer = false
    @State private var showDurationPicker = false
    @State private var showPaywall = false
    @State private var showPromptSheet = false
    @State private var showAmbiencePicker = false
    @State private var selectedPrompt: WritingPrompt?

    // Silent brightness control
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var dragStartBrightness: Double = UIScreen.main.brightness

    private let gatingService = SessionGatingService.shared

    /// Roughly what the days-lit line, the button, the pills and the tab bar
    /// occupy at the bottom. Only used to decide how much room the candle
    /// has; a few points either way just changes the scale slightly.
    private static let bottomBlockHeight: CGFloat = 300

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            // Candle — anchored to top, respects status bar.
            //
            // Scaled, not framed. CandleView draws `intrinsicHeight` from
            // fixed internal sizes and overflows a smaller box instead of
            // shrinking into it, so the old `.frame(height: 320)` let it
            // spill ~100pt past what it claimed. A tall phone has the slack
            // to hide that; on an SE the wax ran straight through the
            // "days lit" line below. Scale against the room actually left.
            GeometryReader { geo in
                let available = max(160, geo.size.height - 44 - Self.bottomBlockHeight)
                let scale = min(1, available / CandleView.intrinsicHeight)

                CandleView(progress: 1.0, isBurning: true, daysLit: viewModel.daysLit)
                    .scaleEffect(scale, anchor: .top)
                    .frame(maxWidth: .infinity)
                    .frame(height: CandleView.intrinsicHeight * scale, alignment: .top)
                    .shadow(color: Theme.Colors.flameOuter.opacity(0.4), radius: 30)
                    .padding(.top, 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // Days lit + button — anchored well below candle
            VStack(spacing: 0) {
                Spacer()

                daysLitSection
                    .padding(.bottom, Theme.Spacing.xl)

                actionButton

                // Three pills, evenly sized so they read as one row rather
                // than three differently-shaped buttons.
                HStack(spacing: Theme.Spacing.xs) {
                    durationPill
                    oraclePill
                    soundPill
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let delta = Double(-value.translation.height) / 300.0
                    brightness = max(0.05, min(1.0, dragStartBrightness + delta))
                    // `take` is idempotent: it captures the user's own
                    // setting the first time only, so a drag here can claim
                    // brightness without stomping the saved value.
                    BrightnessService.shared.take(brightness)
                }
                .onEnded { _ in
                    dragStartBrightness = brightness
                }
        )
        .sheet(isPresented: $showPromptSheet) {
            PromptSheetView(selection: $selectedPrompt)
                .environmentObject(storageService)
        }
        .sheet(isPresented: $showAmbiencePicker) {
            AmbiencePickerSheet(
                storageService: storageService,
                isPremium: gatingService.isPremium,
                onPaywall: {
                    showAmbiencePicker = false
                    showPaywall = true
                }
            )
            .environmentObject(storageService)
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(
                currentDuration: storageService.settings.timerDuration,
                onSelect: { duration in
                    guard duration == AppSettings.defaultTimerDuration || gatingService.isPremium else {
                        showDurationPicker = false
                        showPaywall = true
                        return
                    }
                    storageService.setTimerDuration(duration)
                    showDurationPicker = false
                },
                onDone: { showDurationPicker = false }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseService)
        }
        .fullScreenCover(isPresented: $showTimer) {
            TimerView(prompt: selectedPrompt?.text, onComplete: { _ in
                showTimer = false
                viewModel.refresh()
                presentSessionPaywallIfEarned()
            })
        }
        .onAppear {
            // Sit at whatever the app is already holding, so returning to
            // this tab never jumps the screen.
            brightness = BrightnessService.shared.levelOnAppear(default: brightness)
            dragStartBrightness = brightness
            DispatchQueue.main.async {
                viewModel.refresh()
            }
            Task {
                await purchaseService.checkSubscriptionStatus()
            }
        }
    }

    // MARK: - Session Start Logic
    // Writing is always free and unlimited — the paywall only gates saving
    // a page beyond the free allotment (see CameraViewModel.usePhoto()).
    private func attemptStartSession() {
        showTimer = true
    }

    /// The paywall's one unprompted appearance: once, on returning from the
    /// session that produced the seventh saved page. It used to sit at the
    /// end of onboarding, before the user had written anything; here they
    /// have seven pages and the offer is about keeping them.
    ///
    /// Deliberately after the timer screen has closed, so it never lands on
    /// top of a milestone celebration or the Time Reclaimed reveal.
    private func presentSessionPaywallIfEarned() {
        guard !gatingService.isPremium,
              !storageService.settings.hasSeenSessionPaywall,
              storageService.stats.totalSessions >= 7
        else { return }

        storageService.setHasSeenSessionPaywall(true)
        // A beat after dismissal, or the two full-screen covers collide.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showPaywall = true
        }
    }

    // MARK: - Days Lit Section
    private var daysLitSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                if viewModel.daysLit > 0 {
                    // The candle emoji, not CandleFlameIcon: the flame glyph
                    // reads as part of the app's own chrome, while 🕯️ is the
                    // symbol the app signs its outbound words with.
                    Text("🕯️")
                        .font(Theme.Typography.daysLitDisplay)
                }
                Text(viewModel.daysLitDisplayText)
                    .font(Theme.Typography.daysLitDisplay)
                    .foregroundColor(
                        viewModel.daysLit > 0
                            ? Theme.Colors.primaryText
                            : Theme.Colors.secondaryText
                    )
            }

            Text("\(viewModel.sessionsTodayText)")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    // MARK: - Duration Pill
    private var durationPill: some View {
        pill(icon: "clock", title: storageService.settings.shortFormattedDuration) {
            showDurationPicker = true
        }
    }

    // MARK: - Prompt Pill
    /// Same capsule as the duration pill beside it. Shows the chosen prompt
    /// once there is one, truncated hard — the pill is a reminder, and the
    /// sheet is where the prompt is actually read.
    private var oraclePill: some View {
        // Fixed labels rather than the script text: showing the script
        // itself made the pill change width on every shuffle, which shoved
        // the row around. The script is read in the Oracle sheet.
        //
        // Three states, not two. "Script set" said something was chosen but
        // not what kind, so the one thing you might want to check before
        // starting — am I writing to my own words or the app's — was the one
        // thing it wouldn't tell you.
        pill(icon: "text.quote", title: scriptState) {
            showPromptSheet = true
        }
        // Identified, because "No script" is also the label of a button
        // inside the Oracle sheet this pill opens — matching on the text
        // alone found whichever the query happened to reach first.
        .accessibilityIdentifier("write.scriptPill")
    }

    /// Which of the three the session is in, decided by whether the chosen
    /// script is one the user wrote. Built-ins are constructed fresh rather
    /// than persisted, so membership of `customPrompts` is what separates
    /// them — an id that is not in there came from the fixed set.
    private var scriptState: String {
        guard let selectedPrompt else { return "No question" }
        let isOwn = storageService.customPrompts.contains { $0.id == selectedPrompt.id }
        return isOwn ? "Your question" : "Oracle"
    }

    // MARK: - Sound Pill
    /// Two zones in one capsule. The icon half is the mute switch — the
    /// same master Sound switch as Settings, so the two never disagree.
    /// The word and everything right of it opens ambience: that's the
    /// choice you make deliberately, and it deserves its own doorway.
    ///
    /// The label shows which ambience is selected while one is on; with
    /// none selected it falls back to "Sound". The pill keeps its width
    /// behaviour honest by truncating hard — a reminder, not a display.
    private var soundPill: some View {
        // The pair sits centred with the same 4pt gap as `pill(icon:title:)`,
        // rather than two half-width halves that pushed the icon out to a
        // quarter of the capsule and the label to three quarters — beside
        // two pills whose contents are centred, it read as misaligned.
        HStack(spacing: 4) {
            Button {
                let turningOn = !storageService.settings.soundEnabled
                storageService.setSoundEnabled(turningOn)
                AudioService.shared.setSoundEnabled(turningOn)
                // Tick after the change, so switching on is audible and switching
                // off is silent — the same rule the Settings toggle follows.
                AudioService.shared.playUITick()
            } label: {
                Image(systemName: storageService.settings.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .padding(.leading, Theme.Spacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The pill lost its "Sound" text when it split into a toggle and
            // an ambience label, and the test that keeps this in step with
            // the Settings row was finding it by that word.
            .accessibilityIdentifier("write.soundToggle")

            Button {
                AudioService.shared.playUITick()
                showAmbiencePicker = true
            } label: {
                Text(soundPillLabel)
                    .font(Theme.Typography.caption)
                    .lineLimit(1)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .padding(.trailing, Theme.Spacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .stroke(Theme.Colors.secondaryText.opacity(0.25), lineWidth: 1)
        )
    }

    /// Selected ambience when one is playing; otherwise the plain word.
    private var soundPillLabel: String {
        guard storageService.settings.soundEnabled,
              storageService.settings.ambientSoundEnabled,
              let sound = AudioService.AmbientSound(rawValue: storageService.settings.ambientSoundID) else {
            return "Sound"
        }
        return sound.displayName
    }

    /// One shape for all three pills so the row stays even. Deliberately no
    /// active/inactive colouring: state is carried by the label or the icon,
    /// and the candle stays the only lit thing on this screen.
    /// Ticks before running the action, so every pill gives feedback
    /// whether or not whoever added it remembered to. Duration and Oracle
    /// both shipped silent: the Sound pill is hand-rolled and ticked, these
    /// two came through here and did not, and nothing in the signature said
    /// they had to.
    private func pill(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            AudioService.shared.playUITick()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(Theme.Typography.caption)
                    .lineLimit(1)
            }
            .foregroundColor(Theme.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(
                Capsule()
                    .stroke(Theme.Colors.secondaryText.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Button
    private var actionButton: some View {
        Button {
            attemptStartSession()
        } label: {
            Text(viewModel.buttonText)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

}

// MARK: - Preview
#Preview {
    HomeView()
}

// MARK: - Ambience Picker Sheet (Home)
/// The same list as Settings → Candle → Ambience, opened from the Sound
/// pill's word half. Writes through StorageService directly so the choice
/// is live everywhere — the Settings row reads the same settings.
///
/// Gated like Settings: free users see the list but choosing a sound asks
/// for The Ascent. "Off" is always allowed.
struct AmbiencePickerSheet: View {
    @ObservedObject var storageService: StorageService
    let isPremium: Bool
    let onPaywall: () -> Void

    @Environment(\.dismiss) private var dismiss

    private func choose(enabled: Bool, id: String? = nil) {
        if enabled, !isPremium {
            onPaywall()
            return
        }
        AudioService.shared.playUITick()
        storageService.setAmbientSoundEnabled(enabled)
        if let id { storageService.setAmbientSoundID(id) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.sm) {
                        // Off
                        Button {
                            choose(enabled: false)
                        } label: {
                            ambienceRow(
                                icon: "speaker.slash",
                                iconColor: Theme.Colors.secondaryText,
                                title: "Off",
                                isSelected: !storageService.settings.ambientSoundEnabled
                            )
                        }
                        .buttonStyle(.plain)

                        // Sounds
                        ForEach(AudioService.AmbientSound.allCases) { sound in
                            Button {
                                choose(enabled: true, id: sound.rawValue)
                            } label: {
                                ambienceRow(
                                    icon: sound.icon,
                                    iconColor: Theme.Colors.flameOuter,
                                    title: sound.displayName,
                                    isSelected: storageService.settings.ambientSoundEnabled
                                        && storageService.settings.ambientSoundID == sound.rawValue
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Plays softly while you write.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                            .padding(.top, Theme.Spacing.xs)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Ambience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
    }
}
