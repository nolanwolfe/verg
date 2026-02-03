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
        }
        .sheet(isPresented: $viewModel.showDurationPicker) {
            durationPickerSheet
        }
        .sheet(isPresented: $viewModel.showTimePicker) {
            timePickerSheet
        }
        .alert("Restore Purchases", isPresented: $viewModel.showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.restoreMessage)
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
        }
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
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        SettingsSection(title: "Account") {
            if !purchaseService.isSubscribed {
                SettingsButtonRow(
                    icon: "sparkles",
                    iconColor: Theme.Colors.accent,
                    title: "Upgrade to Pro",
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

            SettingsButtonRow(
                icon: "lock.shield",
                iconColor: .gray,
                title: "Privacy Policy",
                action: { viewModel.openPrivacyPolicy() }
            )

            Divider()
                .background(Theme.Colors.secondaryText.opacity(0.2))

            SettingsButtonRow(
                icon: "doc.text",
                iconColor: .gray,
                title: "Terms of Service",
                action: { viewModel.openTermsOfService() }
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

    // MARK: - Duration Picker Sheet
    private var durationPickerSheet: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(DurationOption.allOptions) { option in
                        Button {
                            viewModel.setDuration(option.duration)
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)

                                Spacer()

                                if viewModel.timerDuration == option.duration {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.small)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Timer Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.showDurationPicker = false
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

// MARK: - Preview
#Preview {
    SettingsView()
}
