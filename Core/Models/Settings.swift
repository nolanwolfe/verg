import Foundation
import SwiftUI

/// The Archive tab's "Days Lit" display — the GitHub-style contribution
/// graph, or the month-grid calendar carried over from Verg 2.1.
enum CalendarStyle: String, CaseIterable, Identifiable, Codable {
    case heatmap
    case monthGrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heatmap: return "Heatmap"
        case .monthGrid: return "Calendar"
        }
    }
}

/// Light, dark, or whatever the phone is set to.
///
/// Light is the default, including for existing installs that predate the
/// setting — the decode falls back to it rather than to `.system`, so the app
/// looks the same on every phone until someone chooses otherwise.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Nil means "don't pin it" — the phone's own setting wins.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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

    /// Days/week the user committed to during onboarding (3, 5, or 7) — nil
    /// if they skipped that step or predate its existence. Drives the
    /// weekly-goal milestone track; purely informational otherwise.
    var weeklyCommitmentDaysPerWeek: Int?

    /// Which "Days Lit" visualization the Archive tab shows.
    var calendarStyle: CalendarStyle
    var appearance: AppearanceMode

    /// Whether the post-onboarding paywall (shown once, after the seventh
    /// saved page) has already been presented. A persisted one-shot rather
    /// than an `== 7` equality check, so it can't re-fire if pages are
    /// deleted and the count crosses seven again.
    var hasSeenSessionPaywall: Bool

    init(
        timerDuration: TimeInterval = AppSettings.defaultTimerDuration,
        soundEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        notificationTime: Date = AppSettings.defaultNotificationTime,
        hasSeenOnboarding: Bool = false,
        isSubscribed: Bool = false,
        hasSeenSetTimerNotice: Bool = false,
        uploadPhotoNoticeShownCount: Int = 0,
        ambientSoundEnabled: Bool = false,
        ambientSoundID: String = "rain",
        weeklySummaryNotificationsEnabled: Bool = false,
        weeklyCommitmentDaysPerWeek: Int? = nil,
        calendarStyle: CalendarStyle = .heatmap,
        appearance: AppearanceMode = .light,
        hasSeenSessionPaywall: Bool = false
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
        self.weeklyCommitmentDaysPerWeek = weeklyCommitmentDaysPerWeek
        self.calendarStyle = calendarStyle
        self.appearance = appearance
        self.hasSeenSessionPaywall = hasSeenSessionPaywall
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
        case weeklyCommitmentDaysPerWeek
        case calendarStyle
        case appearance
        case hasSeenSessionPaywall
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timerDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .timerDuration) ?? AppSettings.defaultTimerDuration
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
        weeklyCommitmentDaysPerWeek = try container.decodeIfPresent(Int.self, forKey: .weeklyCommitmentDaysPerWeek)
        calendarStyle = try container.decodeIfPresent(CalendarStyle.self, forKey: .calendarStyle) ?? .heatmap
        appearance = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .light
        hasSeenSessionPaywall = try container.decodeIfPresent(Bool.self, forKey: .hasSeenSessionPaywall) ?? false
    }

    /// The app's own pitch: a session is 10 minutes. Also what the
    /// onboarding projection screen assumes per session — see
    /// OnboardingProjection.
    static let defaultTimerDuration: TimeInterval = 600

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
        DurationOption(duration: 300,  label: "5 minutes"),
        DurationOption(duration: 600,  label: "10 minutes"),
        DurationOption(duration: 900,  label: "15 minutes")
    ]
}
