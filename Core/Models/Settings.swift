import Foundation

/// App settings and preferences
struct AppSettings: Codable, Equatable {
    var timerDuration: TimeInterval
    var soundEnabled: Bool
    var notificationsEnabled: Bool
    var notificationTime: Date
    var hasSeenOnboarding: Bool
    var isSubscribed: Bool

    // Coach mark notice flags
    var hasSeenSetTimerNotice: Bool
    var uploadPhotoNoticeShownCount: Int

    // Ambient sound during sessions (Pro)
    var ambientSoundEnabled: Bool
    var ambientSoundID: String

    // Weekly "Time Reclaimed" recap notification — off by default; an app
    // about reducing phone use shouldn't generate pings unless asked to.
    var weeklySummaryNotificationsEnabled: Bool

    init(
        timerDuration: TimeInterval = 600, // 10 minutes default
        soundEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        notificationTime: Date = AppSettings.defaultNotificationTime,
        hasSeenOnboarding: Bool = false,
        isSubscribed: Bool = false,
        hasSeenSetTimerNotice: Bool = false,
        uploadPhotoNoticeShownCount: Int = 0,
        ambientSoundEnabled: Bool = false,
        ambientSoundID: String = "rain",
        weeklySummaryNotificationsEnabled: Bool = false
    ) {
        self.timerDuration = timerDuration
        self.soundEnabled = soundEnabled
        self.notificationsEnabled = notificationsEnabled
        self.notificationTime = notificationTime
        self.hasSeenOnboarding = hasSeenOnboarding
        self.isSubscribed = isSubscribed
        self.hasSeenSetTimerNotice = hasSeenSetTimerNotice
        self.uploadPhotoNoticeShownCount = uploadPhotoNoticeShownCount
        self.ambientSoundEnabled = ambientSoundEnabled
        self.ambientSoundID = ambientSoundID
        self.weeklySummaryNotificationsEnabled = weeklySummaryNotificationsEnabled
    }

    // MARK: - Codable (tolerant decoding)
    // Custom decoder so that adding new settings keys never breaks decoding of
    // JSON saved by older app versions — missing keys fall back to defaults.

    enum CodingKeys: String, CodingKey {
        case timerDuration
        case soundEnabled
        case notificationsEnabled
        case notificationTime
        case hasSeenOnboarding
        case isSubscribed
        case hasSeenSetTimerNotice
        case uploadPhotoNoticeShownCount
        case ambientSoundEnabled
        case ambientSoundID
        case weeklySummaryNotificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timerDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .timerDuration) ?? 600
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        notificationTime = try container.decodeIfPresent(Date.self, forKey: .notificationTime) ?? AppSettings.defaultNotificationTime
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        isSubscribed = try container.decodeIfPresent(Bool.self, forKey: .isSubscribed) ?? false
        hasSeenSetTimerNotice = try container.decodeIfPresent(Bool.self, forKey: .hasSeenSetTimerNotice) ?? false
        uploadPhotoNoticeShownCount = try container.decodeIfPresent(Int.self, forKey: .uploadPhotoNoticeShownCount) ?? 0
        ambientSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .ambientSoundEnabled) ?? false
        ambientSoundID = try container.decodeIfPresent(String.self, forKey: .ambientSoundID) ?? "rain"
        weeklySummaryNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklySummaryNotificationsEnabled) ?? false
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
        DurationOption(duration: 600,  label: "10 minutes"),
        DurationOption(duration: 900,  label: "15 minutes"),
        DurationOption(duration: 1200, label: "20 minutes")
    ]
}
