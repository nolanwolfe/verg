import Foundation

/// Aggregated "time reclaimed" writing minutes — daily, weekly, and
/// all-time. Computed fresh from `Session.activeDuration` (foreground-only
/// writing time), never estimated or compared against Screen Time.
struct TimeReclaimedSummary: Equatable {
    var todaySeconds: TimeInterval = 0
    var weekSeconds: TimeInterval = 0
    var lastWeekSeconds: TimeInterval = 0
    var allTimeSeconds: TimeInterval = 0
    var streak: Int = 0

    var weekDeltaSeconds: TimeInterval { weekSeconds - lastWeekSeconds }

    var todayMinutes: Int { Self.minutes(from: todaySeconds) }
    var weekMinutes: Int { Self.minutes(from: weekSeconds) }
    var allTimeMinutes: Int { Self.minutes(from: allTimeSeconds) }
    var weekDeltaMinutes: Int { Self.minutes(from: abs(weekDeltaSeconds)) * (weekDeltaSeconds < 0 ? -1 : 1) }

    static let zero = TimeReclaimedSummary()

    private static func minutes(from seconds: TimeInterval) -> Int {
        Int((seconds / 60).rounded())
    }
}

enum TimeReclaimed {
    /// Sums `activeDuration` across `sessions` into day/week/all-time
    /// buckets. Pure and stateless — pass `now`/`calendar` explicitly in
    /// tests, otherwise the current device time and calendar (so week
    /// boundaries respect the user's locale and current timezone).
    static func summary(
        sessions: [Session],
        streak: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeReclaimedSummary {
        let startOfToday = calendar.startOfDay(for: now)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return TimeReclaimedSummary(streak: streak)
        }
        let startOfWeek = thisWeek.start
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek

        var today: TimeInterval = 0
        var week: TimeInterval = 0
        var lastWeek: TimeInterval = 0
        var allTime: TimeInterval = 0

        for session in sessions {
            let seconds = session.activeDuration
            allTime += seconds
            if session.date >= startOfToday {
                today += seconds
            }
            if session.date >= startOfWeek {
                week += seconds
            } else if session.date >= startOfLastWeek {
                lastWeek += seconds
            }
        }

        return TimeReclaimedSummary(
            todaySeconds: today,
            weekSeconds: week,
            lastWeekSeconds: lastWeek,
            allTimeSeconds: allTime,
            streak: streak
        )
    }

    /// Neutral, factual copy for the post-session confirmation — never
    /// compares to Screen Time, never scolds low numbers.
    /// - `isFirstSessionToday`: the fuller "instead of scrolling" framing
    ///   only applies once per day; later sessions report the running daily
    ///   total instead of repeating a per-session message.
    static func confirmationMessage(todaySeconds: TimeInterval, isFirstSessionToday: Bool) -> String {
        let minutes = Int((todaySeconds / 60).rounded())
        guard minutes > 0 else {
            return "You wrote for less than a minute today."
        }
        let unit = minutes == 1 ? "minute" : "minutes"
        if isFirstSessionToday {
            return "You wrote for \(minutes) \(unit) instead of scrolling."
        } else {
            return "You've written \(minutes) \(unit) today."
        }
    }
}
