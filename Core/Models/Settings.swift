import Foundation

/// App settings and preferences
struct AppSettings: Codable, Equatable {
    var timerDuration: TimeInterval
    var soundEnabled: Bool
    var notificationsEnabled: Bool
    var notificationTime: Date
    var hasSeenOnboarding: Bool
    var isSubscribed: Bool

    init(
        timerDuration: TimeInterval = 10, // 10 seconds for testing
        soundEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        notificationTime: Date = AppSettings.defaultNotificationTime,
        hasSeenOnboarding: Bool = false,
        isSubscribed: Bool = false
    ) {
        self.timerDuration = timerDuration
        self.soundEnabled = soundEnabled
        self.notificationsEnabled = notificationsEnabled
        self.notificationTime = notificationTime
        self.hasSeenOnboarding = hasSeenOnboarding
        self.isSubscribed = isSubscribed
    }

    /// Default notification time (8:00 PM)
    static var defaultNotificationTime: Date {
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Available timer durations
    static let availableDurations: [TimeInterval] = [
        300,  // 5 minutes
        600,  // 10 minutes
        900,  // 15 minutes
        1200, // 20 minutes
        1800  // 30 minutes
    ]

    /// Formatted duration text
    var formattedDuration: String {
        let minutes = Int(timerDuration / 60)
        return "\(minutes) minutes"
    }

    /// Short formatted duration
    var shortFormattedDuration: String {
        let minutes = Int(timerDuration / 60)
        return "\(minutes) min"
    }

    /// Formatted notification time
    var formattedNotificationTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: notificationTime)
    }

    /// Duration in minutes
    var durationInMinutes: Int {
        Int(timerDuration / 60)
    }

    /// Set duration from minutes
    mutating func setDurationMinutes(_ minutes: Int) {
        timerDuration = TimeInterval(minutes * 60)
    }
}

// MARK: - Duration Option
struct DurationOption: Identifiable, Equatable {
    let id = UUID()
    let duration: TimeInterval
    let label: String

    static let allOptions: [DurationOption] = [
        DurationOption(duration: 300, label: "5 minutes"),
        DurationOption(duration: 600, label: "10 minutes"),
        DurationOption(duration: 900, label: "15 minutes"),
        DurationOption(duration: 1200, label: "20 minutes"),
        DurationOption(duration: 1800, label: "30 minutes")
    ]
}
