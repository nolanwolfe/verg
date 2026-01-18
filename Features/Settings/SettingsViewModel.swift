import Foundation
import Combine
import UIKit
import UserNotifications

/// ViewModel for the Settings screen
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var timerDuration: TimeInterval = 10
    @Published var soundEnabled: Bool = true
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTime: Date = AppSettings.defaultNotificationTime

    @Published var showDurationPicker: Bool = false
    @Published var showTimePicker: Bool = false
    @Published var showRestoreAlert: Bool = false
    @Published var restoreMessage: String = ""

    // MARK: - Dependencies
    private let storageService: StorageService
    private let purchaseService: PurchaseService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var formattedDuration: String {
        let minutes = Int(timerDuration / 60)
        return "\(minutes) minutes"
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
        content.title = "Time to Write"
        content.body = "Take 10 minutes to journal your thoughts."
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
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - App Actions
    func rateApp() {
        // Replace with your App Store ID
        if let url = URL(string: "https://apps.apple.com/app/id123456789?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    func shareApp() {
        // Replace with your App Store URL
        let url = URL(string: "https://apps.apple.com/app/id123456789")!
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
        if let url = URL(string: "https://yourapp.com/privacy") {
            UIApplication.shared.open(url)
        }
    }

    func openTermsOfService() {
        if let url = URL(string: "https://yourapp.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}
