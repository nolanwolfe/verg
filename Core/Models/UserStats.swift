import Foundation

/// Tracks how many days in a row the candle has stayed lit
struct UserStats: Codable, Equatable {
    var daysLit: Int
    var longestDaysLit: Int
    var totalSessions: Int
    var lastSessionDate: Date?
    /// Dates (start-of-day) bridged by a premium relight rather than an
    /// actual session — see CandleRelight. Never counted as written days.
    var relitDates: [Date]

    init(
        daysLit: Int = 0,
        longestDaysLit: Int = 0,
        totalSessions: Int = 0,
        lastSessionDate: Date? = nil,
        relitDates: [Date] = []
    ) {
        self.daysLit = daysLit
        self.longestDaysLit = longestDaysLit
        self.totalSessions = totalSessions
        self.lastSessionDate = lastSessionDate
        self.relitDates = relitDates
    }

    // MARK: - Codable (tolerant decoding)
    // Field names changed (currentStreak/longestStreak -> daysLit/longestDaysLit)
    // when "streak" language was retired in favor of "days lit" / candle
    // framing — decode the old keys too so existing users don't lose their
    // count. relitDates is new — missing key decodes to [].
    enum CodingKeys: String, CodingKey {
        case daysLit = "currentStreak"
        case longestDaysLit = "longestStreak"
        case totalSessions
        case lastSessionDate
        case relitDates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        daysLit = try container.decodeIfPresent(Int.self, forKey: .daysLit) ?? 0
        // Clamped, not just decoded. `recordSession` maintains the invariant
        // going forward, but this key was `longestStreak` before the rename
        // and CandleService writes `daysLit` on its own during relight and
        // gap validation — so stored data can arrive with a longest run
        // shorter than the current one, which renders as "3, longest 0".
        let storedLongest = try container.decodeIfPresent(Int.self, forKey: .longestDaysLit) ?? 0
        longestDaysLit = max(storedLongest, daysLit)
        totalSessions = try container.decodeIfPresent(Int.self, forKey: .totalSessions) ?? 0
        lastSessionDate = try container.decodeIfPresent(Date.self, forKey: .lastSessionDate)
        relitDates = try container.decodeIfPresent([Date].self, forKey: .relitDates) ?? []
    }

    /// Check if user has completed a session today
    var hasWrittenToday: Bool {
        guard let lastSession = lastSessionDate else { return false }
        return Calendar.current.isDateInToday(lastSession)
    }

    /// Check if user wrote yesterday (for continuing the candle)
    var wroteYesterday: Bool {
        guard let lastSession = lastSessionDate else { return false }
        return Calendar.current.isDateInYesterday(lastSession)
    }

    /// Update stats after completing a session
    mutating func recordSession() {
        // Always increment total sessions
        totalSessions += 1

        // Only update the candle once per day
        if !hasWrittenToday {
            if wroteYesterday || lastSessionDate == nil {
                // Continue the candle or light a new one
                daysLit += 1
            } else {
                // Candle went out, relight from day one
                daysLit = 1
            }

            // Update longest run if needed
            if daysLit > longestDaysLit {
                longestDaysLit = daysLit
            }
        }

        lastSessionDate = Date()
    }

    /// Formatted "days lit" text
    var daysLitText: String {
        AppStrings.Home.daysLitText(daysLit: daysLit, longestDaysLit: longestDaysLit)
    }
}
