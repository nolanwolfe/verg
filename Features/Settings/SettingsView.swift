import SwiftUI
import RevenueCatUI

/// Settings screen
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var purchaseService: PurchaseService
    @EnvironmentObject private var storageService: StorageService

    @State private var showPromptLibrary = false

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    headerSection

                    // Candle — how a session runs
                    candleSection

                    // Guide — how it's taught, drawn from, and shown back
                    guideSection

                    // Notifications
                    notificationsSection

                    // Account
                    accountSection

                    // About
                    aboutSection

                    // Version
                    versionSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .mask(
                VStack(spacing: 0) {
                    // Fully visible top
                    Rectangle()
                        .fill(Color.black)
                    // Fade out at bottom ~130pt
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 130)
                }
            )
        }
        .sheet(isPresented: $viewModel.showDurationPicker) {
            durationPickerSheet
        }
        .sheet(isPresented: $viewModel.showTimePicker) {
            timePickerSheet
        }
        .sheet(isPresented: $viewModel.showAmbiencePicker) {
            ambiencePickerSheet
        }
        .sheet(isPresented: $viewModel.showCalendarStylePicker) {
            calendarStylePickerSheet
        }
        .sheet(isPresented: $viewModel.showAppearancePicker) {
            appearancePickerSheet
        }
        .sheet(isPresented: $showPromptLibrary) {
            PromptLibraryView()
                .environmentObject(storageService)
        }
        .alert("Restore Purchases", isPresented: $viewModel.showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.restoreMessage)
        }
        .alert("Access Code", isPresented: $viewModel.showRedeemResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.redeemResultMessage)
        }
        .sheet(isPresented: $viewModel.showRedeemSheet) {
            redeemCodeSheet
        }
        .sheet(isPresented: $viewModel.showCustomerCenter) {
            CustomerCenterView()
        }
        .fullScreenCover(isPresented: $viewModel.showPaywall) {
            PaywallView(onSubscribed: {
                viewModel.showPaywall = false
            })
            .environmentObject(purchaseService)
        }
        // Settings can be changed from outside this screen — Sound has a pill
        // on Write — and this view model holds a snapshot, so it re-reads
        // whenever the tab comes back into view.
        .onAppear { viewModel.refresh() }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        Text("Settings")
            .font(Theme.Typography.title)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Candle Section
    /// Duration, sound and ambience — everything about how a session runs.
    /// What it records lives under Guide.
    private var candleSection: some View {
        SettingsSection(title: "Candle") {
            SettingsRow(
                icon: "clock",
                iconColor: Theme.Colors.accent,
                title: "Duration",
                value: viewModel.formattedDuration,
                action: {
                    AudioService.shared.playUITick()
                    viewModel.showDurationPicker = true
                }
            )

            settingsDivider

            SettingsToggleRow(
                icon: "speaker.wave.2",
                iconColor: Theme.Colors.accent,
                title: "Sound",
                isOn: $viewModel.soundEnabled
            )

            settingsDivider

            SettingsRow(
                icon: "music.note",
                iconColor: .blue,
                title: isPremium ? "Ambience" : "Ambience  🔒",
                value: viewModel.ambienceLabel,
                action: {
                    AudioService.shared.playUITick()
                    if isPremium {
                        viewModel.showAmbiencePicker = true
                    } else {
                        viewModel.showPaywall = true
                    }
                }
            )
        }
    }

    private var settingsDivider: some View {
        Divider().background(Theme.Colors.secondaryText.opacity(0.2))
    }

    private var isPremium: Bool {
        purchaseService.isSubscribed || purchaseService.isFriendsAndFamily
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            SettingsToggleRow(
                icon: "bell",
                iconColor: Theme.Colors.accent,
                title: "Daily Reminder",
                isOn: $viewModel.notificationsEnabled
            )

            if viewModel.notificationsEnabled {
                Divider()
                    .background(Theme.Colors.secondaryText.opacity(0.2))

                SettingsRow(
                    icon: "clock",
                    iconColor: .blue,
                    title: "Reminder Time",
                    value: viewModel.formattedNotificationTime,
                    action: { viewModel.showTimePicker = true }
                )
            }

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsToggleRow(
                icon: "hourglass",
                iconColor: Theme.Colors.accent,
                title: "Weekly Recap",
                isOn: $viewModel.weeklySummaryNotificationsEnabled
            )
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        SettingsSection(title: "Account") {
            // One row whether subscribed or not — it reports its own state
            // instead of appearing and disappearing, so the section keeps a
            // stable three rows.
            SettingsSwitchButtonRow(
                // Closest thing SF Symbols has to a single wheat stalk, and
                // it echoes the laurel on the paywall.
                icon: "laurel.leading",
                iconColor: Theme.Colors.accent,
                title: "The Golden Age",
                isOn: isPremium,
                action: {
                    AudioService.shared.playUITick()
                    if purchaseService.isSubscribed {
                        viewModel.manageSubscription()
                    } else {
                        viewModel.showPaywall = true
                    }
                }
            )


            settingsDivider

            SettingsRow(
                icon: "circle.lefthalf.filled",
                iconColor: .blue,
                title: "Appearance",
                value: viewModel.appearance.displayName,
                action: {
                    AudioService.shared.playUITick()
                    viewModel.showAppearancePicker = true
                }
            )

            settingsDivider

            SettingsButtonRow(
                icon: "arrow.clockwise",
                iconColor: Theme.Colors.accent,
                title: "Restore",
                action: {
                    AudioService.shared.playUITick()
                    viewModel.restorePurchases()
                }
            )

            settingsDivider

            SettingsButtonRow(
                icon: "gift",
                iconColor: Theme.Colors.accent,
                title: purchaseService.isFriendsAndFamily ? "Friends & Family Access Active" : "Redeem Access Code",
                action: {
                    guard !purchaseService.isFriendsAndFamily else { return }
                    AudioService.shared.playUITick()
                    viewModel.showRedeemSheet = true
                }
            )
        }
    }

    // MARK: - Guide Section
    /// How the ritual is taught, what it draws from, and how it's shown back.
    private var guideSection: some View {
        SettingsSection(title: "Guide") {
            SettingsButtonRow(
                icon: "book",
                iconColor: Theme.Colors.accent,
                title: "How to write with Verg 🕯️",
                action: {
                    AudioService.shared.playUITick()
                    NotificationCenter.default.post(name: .onboardingReplayRequested, object: nil)
                }
            )

            settingsDivider

            SettingsButtonRow(
                icon: "text.quote",
                iconColor: Theme.Colors.accent,
                title: "The Oracle",
                action: {
                    AudioService.shared.playUITick()
                    showPromptLibrary = true
                }
            )

            settingsDivider

            SettingsRow(
                icon: "calendar",
                iconColor: .blue,
                title: "History",
                value: viewModel.calendarStyle.displayName,
                action: {
                    AudioService.shared.playUITick()
                    viewModel.showCalendarStylePicker = true
                }
            )

        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsButtonRow(
                icon: "star",
                iconColor: Theme.Colors.accent,
                title: "Rate Verg",
                action: { viewModel.rateApp() }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "square.and.arrow.up",
                // Blue: sharing is a system action, and the share sheet it
                // opens is Apple's, not ours.
                iconColor: .blue,
                title: "Share Verg",
                action: { viewModel.shareApp() }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsLinkRow(
                icon: "lock.shield",
                // The two legal rows stay plain white — gilding a privacy
                // policy is the wrong tone, and they are the only rows here
                // that leave the app.
                iconColor: .white,
                title: "Privacy Policy",
                url: URL(string: "https://nolanwolfe.github.io/verg/privacy")!
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsLinkRow(
                icon: "doc.text",
                iconColor: .white,
                title: "Terms of Service",
                url: URL(string: "https://nolanwolfe.github.io/verg/terms")!
            )
        }
    }

    // MARK: - DEBUG Section
    #if DEBUG
    private var debugSection: some View {
        SettingsSection(title: "Debug") {
            SettingsButtonRow(
                icon: "creditcard",
                iconColor: Theme.Colors.accent,
                title: "Test Paywall",
                action: { viewModel.showPaywall = true }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "arrow.counterclockwise",
                iconColor: Theme.Colors.accent,
                title: "Reset Onboarding",
                action: { StorageService.shared.setHasSeenOnboarding(false) }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "trash",
                iconColor: Theme.Colors.accent,
                title: "Reset Free Session Count",
                action: {
                    StorageService.shared.resetForTesting()
                    print("[DEBUG] Free session count reset. Sessions: \(StorageService.shared.sessions.count)")
                }
            )

            // Display current session count
            HStack {
                Text("Sessions: \(StorageService.shared.sessions.count)")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
                Text("Premium: \(purchaseService.isSubscribed ? "Yes" : "No")")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.top, Theme.Spacing.xxs)
        }
    }
    #endif

    // MARK: - Version Section
    private var versionSection: some View {
        Text(viewModel.appVersion)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
            .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Redeem Code Sheet
    private var redeemCodeSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    Text("Enter the access code you received. The Golden Age, on us.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.md)

                    TextField("Access code", text: $viewModel.redeemCodeText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, Theme.Spacing.md)

                    Button {
                        viewModel.redeemAccessCode()
                    } label: {
                        Text("Redeem")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Theme.Spacing.md)
                    .disabled(viewModel.redeemCodeText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(.top, Theme.Spacing.lg)
            }
            .navigationTitle("Redeem Access Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.redeemCodeText = ""
                        viewModel.showRedeemSheet = false
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Appearance Picker Sheet
    private var appearancePickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            AudioService.shared.playUITick()
                            viewModel.appearance = mode
                            viewModel.showAppearancePicker = false
                        } label: {
                            HStack {
                                Text(mode.displayName)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if viewModel.appearance == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        }
                        .accessibilityIdentifier("appearance.\(mode.rawValue)")
                    }

                    Text("The candle screens stay dark either way — they dim your screen on purpose.")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.xs)

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { viewModel.showAppearancePicker = false }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Calendar Style Picker Sheet
    private var calendarStylePickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(CalendarStyle.allCases) { style in
                        Button {
                            AudioService.shared.playUITick()
                            viewModel.calendarStyle = style
                            viewModel.showCalendarStylePicker = false
                        } label: {
                            HStack {
                                Text(style.displayName)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if viewModel.calendarStyle == style {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        }
                        .accessibilityIdentifier("history.\(style.rawValue)")
                    }
                }
                .padding(Theme.Spacing.md)
            }
            // "Calendar Style" was left over from when the setting was named
            // for one of its own options; the row says History, so does this.
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { viewModel.showCalendarStylePicker = false }
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Duration Picker Sheet
    private var durationPickerSheet: some View {
        DurationPickerSheet(
            currentDuration: viewModel.timerDuration,
            onSelect: { viewModel.setDuration($0) },
            onDone: { viewModel.showDurationPicker = false }
        )
    }

    // MARK: - Ambience Picker Sheet
    private var ambiencePickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.sm) {
                        // Off
                        Button {
                            viewModel.ambientSoundEnabled = false
                        } label: {
                            HStack {
                                Image(systemName: "speaker.slash")
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .frame(width: 24)
                                Text("Off")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if !viewModel.ambientSoundEnabled {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        }

                        // Sounds
                        ForEach(AudioService.AmbientSound.allCases) { sound in
                            Button {
                                viewModel.ambientSoundEnabled = true
                                viewModel.ambientSoundID = sound.rawValue
                            } label: {
                                HStack {
                                    Image(systemName: sound.icon)
                                        .foregroundColor(Theme.Colors.flameOuter)
                                        .frame(width: 24)
                                    Text(sound.displayName)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Spacer()
                                    if viewModel.ambientSoundEnabled && viewModel.ambientSoundID == sound.rawValue {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Theme.Colors.accent)
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                            }
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
                    Button("Done") {
                        viewModel.showAmbiencePicker = false
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Time Picker Sheet
    private var timePickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                DatePicker(
                    "Reminder Time",
                    selection: $viewModel.notificationTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            }
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.showTimePicker = false
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title.uppercased())
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .padding(.leading, Theme.Spacing.sm)

            VStack(spacing: 0) {
                content
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Text(value)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
        .accessibilityIdentifier("settings.\(title)")
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Theme.Colors.toggleTint)
                .accessibilityIdentifier("settings.toggle.\(title)")
                // Every switch ticks. Haptic always; the sound follows the
                // Sound setting, which this row may itself be flipping — so
                // turning sound off is silent and turning it on is not.
                .onChange(of: isOn) { _, _ in
                    AudioService.shared.playUITick()
                }
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

// MARK: - Settings Switch Button Row
/// Looks exactly like `SettingsToggleRow` — icon, title, switch — but the
/// switch is a static indicator, not a live `Toggle`. For rows whose state
/// isn't a local bool to flip in place (subscription status): tapping
/// anywhere routes to the real flow (paywall / manage subscription) instead
/// of optimistically flipping and snapping back.
struct SettingsSwitchButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Capsule()
                    .fill(isOn ? Theme.Colors.toggleTint : Color(.systemGray5))
                    .frame(width: 51, height: 31)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 27, height: 27)
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                            .padding(2),
                        alignment: isOn ? .trailing : .leading
                    )
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
    }
}

// MARK: - Settings Button Row
struct SettingsButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
        .accessibilityIdentifier("settings.\(title)")
    }
}

// MARK: - Settings Link Row
struct SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
        .accessibilityIdentifier("settings.\(title)")
    }
}

// MARK: - Duration Picker Sheet (shared with Home)
struct DurationPickerSheet: View {
    let currentDuration: TimeInterval
    let onSelect: (TimeInterval) -> Void
    let onDone: () -> Void

    @State private var customText: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.sm) {
                    // Presets
                    ForEach(DurationOption.allOptions) { option in
                        Button {
                            onSelect(option.duration)
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                if currentDuration == option.duration {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                        }
                    }

                    // Custom — clean tap-to-type field, MM:SS, number pad
                    HStack {
                        TextField("00:00", text: $customText)
                            .keyboardType(.numberPad)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .autocorrectionDisabled()
                            .onChange(of: customText) { _, val in
                                let digits = val.filter { $0.isNumber }
                                if digits.count >= 2 && !val.contains(":") {
                                    let mm = String(digits.prefix(2))
                                    let ss = String(digits.dropFirst(2).prefix(2))
                                    let formatted = ss.isEmpty ? mm : "\(mm):\(ss)"
                                    DispatchQueue.main.async {
                                        customText = formatted
                                    }
                                }
                            }

                        Spacer()

                        if !customText.isEmpty {
                            Button("Set") {
                                if let duration = SettingsViewModel.parseCustomDuration(customText) {
                                    customText = ""
                                    onSelect(duration)
                                }
                            }
                            .foregroundColor(Theme.Colors.accent)
                            .font(Theme.Typography.body.weight(.semibold))
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Timer Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDone()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}
