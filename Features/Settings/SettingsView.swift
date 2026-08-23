import SwiftUI
import RevenueCatUI

/// Settings screen
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var purchaseService: PurchaseService

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    headerSection

                    // Timer settings
                    timerSection

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
    }

    // MARK: - Header Section
    private var headerSection: some View {
        Text("Settings")
            .font(Theme.Typography.title)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Timer Section
    private var timerSection: some View {
        SettingsSection(title: "Timer") {
            SettingsRow(
                icon: "clock",
                iconColor: Theme.Colors.accent,
                title: "Duration",
                value: viewModel.formattedDuration,
                action: { viewModel.showDurationPicker = true }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsToggleRow(
                icon: "speaker.wave.2",
                iconColor: .orange,
                title: "Sound",
                isOn: $viewModel.soundEnabled
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsRow(
                icon: "music.note",
                iconColor: .purple,
                title: isPremium ? "Ambience" : "Ambience  🔒",
                value: viewModel.ambienceLabel,
                action: {
                    if isPremium {
                        viewModel.showAmbiencePicker = true
                    } else {
                        viewModel.showPaywall = true
                    }
                }
            )
        }
    }

    private var isPremium: Bool {
        purchaseService.isSubscribed || purchaseService.isFriendsAndFamily
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            SettingsToggleRow(
                icon: "bell",
                iconColor: .red,
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
            if !purchaseService.isSubscribed {
                SettingsButtonRow(
                    icon: "sparkles",
                    iconColor: Theme.Colors.accent,
                    title: "Upgrade — On the Verg of Becoming",
                    action: { viewModel.showPaywall = true }
                )

                Divider()
                    .background(Theme.Colors.secondaryText.opacity(0.2))
            }

            SettingsButtonRow(
                icon: "arrow.clockwise",
                iconColor: .green,
                title: "Restore Purchases",
                action: { viewModel.restorePurchases() }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "gift",
                iconColor: .purple,
                title: purchaseService.isFriendsAndFamily ? "Friends & Family Access Active" : "Redeem Access Code",
                action: {
                    if !purchaseService.isFriendsAndFamily {
                        viewModel.showRedeemSheet = true
                    }
                }
            )

            if purchaseService.isSubscribed {
                Divider()
                    .background(Theme.Colors.secondaryText.opacity(0.2))

                SettingsButtonRow(
                    icon: "creditcard",
                    iconColor: Theme.Colors.accent,
                    title: "Manage Subscription",
                    action: { viewModel.manageSubscription() }
                )
            }

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "cart",
                iconColor: .yellow,
                title: "View Subscription Options",
                action: { viewModel.showPaywall = true }
            )
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsButtonRow(
                icon: "star",
                iconColor: .yellow,
                title: "Rate Verg",
                action: { viewModel.rateApp() }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "square.and.arrow.up",
                iconColor: .blue,
                title: "Share Verg",
                action: { viewModel.shareApp() }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsLinkRow(
                icon: "lock.shield",
                iconColor: .gray,
                title: "Privacy Policy",
                url: URL(string: "https://nolanwolfe.github.io/verg/privacy")!
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsLinkRow(
                icon: "doc.text",
                iconColor: .gray,
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
                iconColor: .purple,
                title: "Test Paywall",
                action: { viewModel.showPaywall = true }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "arrow.counterclockwise",
                iconColor: .red,
                title: "Reset Onboarding",
                action: { StorageService.shared.setHasSeenOnboarding(false) }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "trash",
                iconColor: .orange,
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
                    Text("Enter the access code you received to unlock unlimited access to Verg.")
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
                        .cornerRadius(Theme.CornerRadius.small)
                    }

                    // Sounds
                    ForEach(AudioService.AmbientSound.allCases) { sound in
                        Button {
                            viewModel.ambientSoundEnabled = true
                            viewModel.ambientSoundID = sound.rawValue
                        } label: {
                            HStack {
                                Image(systemName: sound.icon)
                                    .foregroundColor(Color(hex: "FF9500"))
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
                            .cornerRadius(Theme.CornerRadius.small)
                        }
                    }

                    Text("Plays softly while you write.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                        .padding(.top, Theme.Spacing.xs)
                }
                .padding(Theme.Spacing.md)
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
        .presentationDetents([.medium])
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
            .cornerRadius(Theme.CornerRadius.medium)
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
                .tint(Theme.Colors.accent)
        }
        .padding(.vertical, Theme.Spacing.xxs)
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
                            .cornerRadius(Theme.CornerRadius.small)
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
                    .cornerRadius(Theme.CornerRadius.small)
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
