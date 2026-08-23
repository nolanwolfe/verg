import Foundation

/// Aggregated "time reclaimed" writing minutes — daily, weekly, and
/// all-time. Computed fresh from `Session.activeDuration` (foreground-only
/// writing time), never estimated or compared against Screen Time.
struct TimeReclaimedSummary: Equatable {
    var todaySeconds: TimeInterval = 0
    var weekSeconds: TimeInterval = 0
    var lastWeekSeconds: TimeInterval = 0
    var allTimeSeconds: TimeInterval = 0
    var daysLit: Int = 0

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

/// The pieces of the post-session reveal, kept separate from a single
/// sentence so the full-screen card can give the number its own visual
/// weight instead of burying it in prose.
struct TimeReclaimedMoment: Equatable {
    /// Minutes in the session that just ended — not the day's running
    /// total. The card names it "Your session", so it has to be the session.
    let minutes: Int
    /// Minutes written across the whole day, carried only when today holds
    /// more than the one session just finished. Nil on the first session,
    /// where it would only repeat `minutes` back.
    let todayMinutes: Int?
    let daysLit: Int

    var eyebrow: String { "Your session" }

    var unit: String { minutes == 1 ? "minute" : "minutes" }

    /// What the minutes were spent instead of. The whole premise of the
    /// number, so it stays on the card rather than being implied.
    var framing: String { "instead of scrolling." }

    /// Second line, on a day with more than one session.
    var todayLine: String? {
        guard let todayMinutes else { return nil }
        return "\(todayMinutes) minutes today"
    }

    /// The candle, formatted exactly as the Write screen formats it — the
    /// emoji from two days on, per `AppStrings.Home.daysLitBadge`.
    var daysLitLine: String? {
        AppStrings.Home.daysLitBadge(daysLit)
    }

    /// One coherent sentence — used for VoiceOver and anywhere a single
    /// string is more appropriate than the split layout.
    var accessibleSentence: String {
        guard minutes > 0 else { return "Your session ran less than a minute." }
        var sentence = "Your session: \(minutes) \(unit) \(framing)"
        if let todayLine { sentence += " \(todayLine)." }
        if let daysLitLine { sentence += " \(daysLitLine)" }
        return sentence
    }
}

enum TimeReclaimed {
    /// Sums `activeDuration` across `sessions` into day/week/all-time
    /// buckets. Pure and stateless — pass `now`/`calendar` explicitly in
    /// tests, otherwise the current device time and calendar (so week
    /// boundaries respect the user's locale and current timezone).
    static func summary(
        sessions: [Session],
        daysLit: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeReclaimedSummary {
        let startOfToday = calendar.startOfDay(for: now)
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return TimeReclaimedSummary(daysLit: daysLit)
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
            daysLit: daysLit
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

    /// Same copy rules as `confirmationMessage`, split into pieces for the
    /// full-screen session-end reveal.
    static func moment(
        sessionSeconds: TimeInterval,
        todaySeconds: TimeInterval,
        daysLit: Int
    ) -> TimeReclaimedMoment {
        let minutes = Int((sessionSeconds / 60).rounded())
        let dayTotal = Int((todaySeconds / 60).rounded())
        return TimeReclaimedMoment(
            minutes: minutes,
            // Only when the day genuinely holds more than this session.
            todayMinutes: dayTotal > minutes ? dayTotal : nil,
            daysLit: daysLit
        )
    }
}
