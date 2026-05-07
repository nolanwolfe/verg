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
    @Published var customDurationText: String = ""
    @Published var soundEnabled: Bool = true
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTime: Date = AppSettings.defaultNotificationTime

    @Published var showDurationPicker: Bool = false
    @Published var showTimePicker: Bool = false
    @Published var showRestoreAlert: Bool = false
    @Published var restoreMessage: String = ""
    @Published var showCustomerCenter: Bool = false
    @Published var showPaywall: Bool = false
    @Published var showRedeemSheet: Bool = false
    @Published var redeemCodeText: String = ""
    @Published var showRedeemResult: Bool = false
    @Published var redeemResultMessage: String = ""

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
    }

    // MARK: - Actions
    func setDuration(_ duration: TimeInterval) {
        timerDuration = duration
        showDurationPicker = false
    }

    /// Parse MM:SS input and apply as custom duration
    func applyCustomDuration() {
        let text = customDurationText.trimmingCharacters(in: .whitespaces)
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let seconds = TimeInterval(parts[0] * 60 + parts[1])
        let clamped = min(max(seconds, 1), 3600)
        timerDuration = clamped
        customDurationText = ""
        showDurationPicker = false
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

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()

        // Remove existing notifications
        center.removeAllPendingNotificationRequests()

        // Create content
        let content = UNMutableNotificationContent()
        content.title = "Begin Writing"
        let mins = Int(timerDuration / 60)
        let durationLabel = mins > 0 ? "\(mins) minutes" : "\(Int(timerDuration)) seconds"
        content.body = "Take \(durationLabel) to journal your thoughts."
        content.sound = .default

        // Create trigger for daily notification
        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create request
        let request = UNNotificationRequest(
            identifier: "verg.daily.reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Access Code Redemption
    func redeemAccessCode() {
        let code = redeemCodeText
        Task { @MainActor in
            let success = purchaseService.redeemAccessCode(code)
            redeemResultMessage = success
                ? "Access granted! You now have unlimited access to Verg."
                : "Invalid code. Please double-check and try again."
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
                    ? "Purchases restored successfully!"
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
            activityItems: ["Check out Verg - a journaling timer app!", url],
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
