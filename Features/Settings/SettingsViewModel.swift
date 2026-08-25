import Foundation
import Combine
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// ViewModel for the Settings screen
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var timerDuration: TimeInterval = 600
    @Published var soundEnabled: Bool = true
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTime: Date = AppSettings.defaultNotificationTime
    @Published var ambientSoundEnabled: Bool = false
    @Published var ambientSoundID: String = "rain"
    @Published var weeklySummaryNotificationsEnabled: Bool = false
    @Published var calendarStyle: CalendarStyle = .heatmap
    @Published var appearance: AppearanceMode = .system

    @Published var showDurationPicker: Bool = false
    @Published var showAmbiencePicker: Bool = false
    @Published var showCalendarStylePicker: Bool = false
    @Published var showAppearancePicker: Bool = false
    @Published var showTimePicker: Bool = false
    @Published var showRestoreAlert: Bool = false
    @Published var restoreMessage: String = ""
    @Published var showCustomerCenter: Bool = false
    @Published var showPaywall: Bool = false
    @Published var showRedeemSheet: Bool = false
    @Published var redeemCodeText: String = ""
    @Published var showRedeemResult: Bool = false
    @Published var redeemResultMessage: String = ""

    // MARK: - App Lock
    /// Drives the Lock App switch. Both directions open a sheet and both can
    /// be cancelled, so this is a *request* rather than the truth — the truth
    /// is `AppLockService.isEnabled`, and `finishAppLock…` reconciles the two.
    @Published var appLockEnabled: Bool = false
    @Published var showAppLockSetup: Bool = false
    @Published var showAppLockConfirm: Bool = false

    /// Set while the view model is putting the switch back after a cancel,
    /// so the binding's own sink doesn't read that correction as a new tap
    /// and open the sheet again.
    private var isReconcilingAppLock = false

    @MainActor
    var appLock: AppLockService { .shared }

    // MARK: - Dependencies
    private let storageService: StorageService
    private let purchaseService: PurchaseService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var formattedDuration: String {
        let total = Int(timerDuration)
        if total < 60 {
            return "\(total) sec"
        } else if total % 60 == 0 {
            let mins = total / 60
            return mins == 1 ? "1 minute" : "\(mins) minutes"
        } else {
            let mins = total / 60
            let secs = total % 60
            return "\(mins)m \(secs)s"
        }
    }

    var formattedNotificationTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: notificationTime)
    }

    var ambienceLabel: String {
        guard ambientSoundEnabled,
              let sound = AudioService.AmbientSound(rawValue: ambientSoundID) else {
            return "Off"
        }
        return sound.displayName
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    // MARK: - Initialization
    init(
        storageService: StorageService = .shared,
        purchaseService: PurchaseService = .shared
    ) {
        self.storageService = storageService
        self.purchaseService = purchaseService
        loadSettings()
        setupBindings()
    }

    // MARK: - Setup
    private func loadSettings() {
        let settings = storageService.settings
        timerDuration = settings.timerDuration
        soundEnabled = settings.soundEnabled
        notificationsEnabled = settings.notificationsEnabled
        notificationTime = settings.notificationTime
        ambientSoundEnabled = settings.ambientSoundEnabled
        ambientSoundID = settings.ambientSoundID
        weeklySummaryNotificationsEnabled = settings.weeklySummaryNotificationsEnabled
        calendarStyle = settings.calendarStyle
        appearance = settings.appearance
        // The lock's truth lives in the Keychain, not the settings file.
        appLockEnabled = MainActor.assumeIsolated { AppLockService.shared.isEnabled }
    }

    /// Re-read from storage, assigning only what actually differs.
    ///
    /// The published properties here are a *snapshot* taken at init, and the
    /// object outlives a tab switch — so a setting changed anywhere else went
    /// unnoticed. The Sound pill on Write is the same switch as the Sound row
    /// here, and flipping it there left this row showing the old value.
    ///
    /// Only-if-different matters: each property has a `dropFirst` sink that
    /// writes back to storage, and assigning an identical value would spend a
    /// save and, for notifications, re-schedule them for nothing.
    func refresh() {
        let settings = storageService.settings
        if timerDuration != settings.timerDuration { timerDuration = settings.timerDuration }
        if soundEnabled != settings.soundEnabled { soundEnabled = settings.soundEnabled }
        if notificationsEnabled != settings.notificationsEnabled { notificationsEnabled = settings.notificationsEnabled }
        if notificationTime != settings.notificationTime { notificationTime = settings.notificationTime }
        if ambientSoundEnabled != settings.ambientSoundEnabled { ambientSoundEnabled = settings.ambientSoundEnabled }
        if ambientSoundID != settings.ambientSoundID { ambientSoundID = settings.ambientSoundID }
        if weeklySummaryNotificationsEnabled != settings.weeklySummaryNotificationsEnabled {
            weeklySummaryNotificationsEnabled = settings.weeklySummaryNotificationsEnabled
        }
        if calendarStyle != settings.calendarStyle { calendarStyle = settings.calendarStyle }
        if appearance != settings.appearance { appearance = settings.appearance }

        // Reconciled, not assigned: a plain write would fire the toggle's
        // sink and re-open the set-up sheet every time the tab came back.
        let locked = MainActor.assumeIsolated { AppLockService.shared.isEnabled }
        MainActor.assumeIsolated { reconcileAppLockSwitch(to: locked) }
    }

    private func setupBindings() {
        // Save changes automatically
        $timerDuration
            .dropFirst()
            .sink { [weak self] duration in
                self?.storageService.setTimerDuration(duration)
            }
            .store(in: &cancellables)

        $soundEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.storageService.setSoundEnabled(enabled)
                // AudioService keeps its own copy; without this the setting
                // would silence the bells but not the interface ticks.
                AudioService.shared.setSoundEnabled(enabled)
                // Sound is the master switch: off takes ambience with it, and
                // the ambience row must show that immediately.
                if !enabled, self?.ambientSoundEnabled == true {
                    self?.ambientSoundEnabled = false
                }
            }
            .store(in: &cancellables)

        $notificationsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.handleNotificationToggle(enabled)
            }
            .store(in: &cancellables)

        $notificationTime
            .dropFirst()
            .sink { [weak self] time in
                self?.storageService.setNotificationTime(time)
                if self?.notificationsEnabled == true {
                    self?.scheduleNotification()
                }
            }
            .store(in: &cancellables)

        $ambientSoundEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.storageService.setAmbientSoundEnabled(enabled)
            }
            .store(in: &cancellables)

        $ambientSoundID
            .dropFirst()
            .sink { [weak self] id in
                self?.storageService.setAmbientSoundID(id)
            }
            .store(in: &cancellables)

        $weeklySummaryNotificationsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.handleWeeklySummaryToggle(enabled)
            }
            .store(in: &cancellables)

        $calendarStyle
            .dropFirst()
            .sink { [weak self] style in
                self?.storageService.setCalendarStyle(style)
            }
            .store(in: &cancellables)

        $appearance
            .dropFirst()
            .sink { [weak self] mode in
                self?.storageService.setAppearance(mode)
            }
            .store(in: &cancellables)

        $appLockEnabled
            .dropFirst()
            .sink { [weak self] wants in
                self?.handleAppLockToggle(wants)
            }
            .store(in: &cancellables)
    }

    // MARK: - App Lock

    private func handleAppLockToggle(_ wants: Bool) {
        // Ignore the echo from our own correction after a cancelled sheet.
        guard !isReconcilingAppLock else { return }
        MainActor.assumeIsolated {
            guard wants != appLock.isEnabled else { return }
            if wants {
                showAppLockSetup = true
            } else {
                // Turning the lock off needs the code. Without that check the
                // lock is decorative — anyone holding the unlocked phone
                // could flip this switch and walk in.
                showAppLockConfirm = true
            }
        }
    }

    @MainActor
    func finishAppLockSetup(didEnable: Bool) {
        showAppLockSetup = false
        reconcileAppLockSwitch(to: didEnable)
    }

    @MainActor
    func finishAppLockDisable(didDisable: Bool) {
        showAppLockConfirm = false
        // Cancelled, or the wrong code: the lock is still on, so the switch
        // goes back on with it.
        reconcileAppLockSwitch(to: !didDisable)
    }

    /// Put the switch where the service actually is, without re-triggering.
    @MainActor
    private func reconcileAppLockSwitch(to value: Bool) {
        guard appLockEnabled != value else { return }
        isReconcilingAppLock = true
        appLockEnabled = value
        isReconcilingAppLock = false
    }

    // MARK: - Actions
    func setDuration(_ duration: TimeInterval) {
        let isPremium = MainActor.assumeIsolated { SessionGatingService.shared.isPremium }
        guard duration == AppSettings.defaultTimerDuration || isPremium else {
            showDurationPicker = false
            showPaywall = true
            return
        }
        timerDuration = duration
        showDurationPicker = false
    }

    /// Parse MM:SS input into a clamped duration (1s...60min). Shared by
    /// the settings and home duration pickers.
    static func parseCustomDuration(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let seconds = TimeInterval(parts[0] * 60 + parts[1])
        return min(max(seconds, 1), 3600)
    }

    // MARK: - Notifications
    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        } else {
            cancelNotifications()
        }
        storageService.setNotificationsEnabled(enabled)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.scheduleNotification()
                } else {
                    self?.notificationsEnabled = false
                }
            }
        }
    }

    private static let dailyReminderID = "verg.daily.reminder"
    private static let weeklySummaryID = "verg.weekly.summary"

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()

        // Remove only this notification's prior schedule — the weekly
        // summary is a separate identifier and shouldn't be touched here.
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])

        // Create content
        let content = UNMutableNotificationContent()
        content.title = "Begin Writing"
        let mins = Int(timerDuration / 60)
        let durationLabel = mins > 0 ? "\(mins) minutes" : "\(Int(timerDuration)) seconds"
        content.body = "Take \(durationLabel) to write."
        content.sound = .default

        // Create trigger for daily notification
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create request
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])
    }

    // MARK: - Weekly Summary Notification
    /// Optional, off by default. Static copy only — without a background
    /// refresh mechanism we can't guarantee the actual weekly total is
    /// fresh at fire time, and showing a stale number would be worse than
    /// a plain nudge to open the app.
    private func handleWeeklySummaryToggle(_ enabled: Bool) {
        if enabled {
            requestWeeklySummaryPermission()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.weeklySummaryID])
        }
        storageService.setWeeklySummaryNotificationsEnabled(enabled)
    }

    private func requestWeeklySummaryPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                if granted {
                    self?.scheduleWeeklySummaryNotification()
                } else {
                    self?.weeklySummaryNotificationsEnabled = false
                }
            }
        }
    }

    private func scheduleWeeklySummaryNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklySummaryID])

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Verg 🕯️"
        content.body = "Time reclaimed this week."
        content.sound = .default

        // Sunday evening — a natural weekly-recap moment
        var dateComponents = DateComponents()
        dateComponents.weekday = 1
        dateComponents.hour = 18
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.weeklySummaryID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Access Code Redemption
    func redeemAccessCode() {
        let code = redeemCodeText
        Task { @MainActor in
            let success = purchaseService.redeemAccessCode(code)
            redeemResultMessage = success
                ? "Access granted. Unlimited access to Verg."
                : "Invalid code. Check it and try again."
            redeemCodeText = ""
            showRedeemSheet = false
            showRedeemResult = true
        }
    }

    // MARK: - Purchases
    func restorePurchases() {
        Task {
            let success = await purchaseService.restorePurchases()
            await MainActor.run {
                restoreMessage = success
                    ? "Purchases restored."
                    : "No purchases found to restore."
                showRestoreAlert = true
            }
        }
    }

    func manageSubscription() {
        showCustomerCenter = true
    }

    // MARK: - App Actions
    func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id6758077555?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    func shareApp() {
        let url = URL(string: "https://apps.apple.com/app/id6758077555")!
        let activityVC = UIActivityViewController(
            activityItems: ["Verg 🕯️ — light a candle. Write until it burns out.", url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    func openPrivacyPolicy() {
        if let url = URL(string: "https://nolanwolfe.github.io/verg/privacy") {
            UIApplication.shared.open(url)
        }
    }

    func openTermsOfService() {
        if let url = URL(string: "https://nolanwolfe.github.io/verg/terms") {
            UIApplication.shared.open(url)
        }
    }
}
