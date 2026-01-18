import Foundation

/// Tracks user statistics and streak information
struct UserStats: Codable, Equatable {
    var currentStreak: Int
    var longestStreak: Int
    var totalSessions: Int
    var lastSessionDate: Date?

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalSessions: Int = 0,
        lastSessionDate: Date? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalSessions = totalSessions
        self.lastSessionDate = lastSessionDate
    }

    /// Check if user has completed a session today
    var hasWrittenToday: Bool {
        guard let lastSession = lastSessionDate else { return false }
        return Calendar.current.isDateInToday(lastSession)
    }

    /// Check if user wrote yesterday (for streak continuation)
    var wroteYesterday: Bool {
        guard let lastSession = lastSessionDate else { return false }
        return Calendar.current.isDateInYesterday(lastSession)
    }

    /// Update stats after completing a session
    mutating func recordSession() {
        // Always increment total sessions
        totalSessions += 1

        // Only update streak logic once per day
        if !hasWrittenToday {
            if wroteYesterday || lastSessionDate == nil {
                // Continue streak or start new one
                currentStreak += 1
            } else {
                // Streak broken, start over
                currentStreak = 1
            }

            // Update longest streak if needed
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
        }

        lastSessionDate = Date()
    }

    /// Validate streak on app launch (reset if broken)
    mutating func validateStreak() {
        guard let lastSession = lastSessionDate else {
            currentStreak = 0
            return
        }

        // If last session was not today or yesterday, streak is broken
        if !Calendar.current.isDateInToday(lastSession) &&
           !Calendar.current.isDateInYesterday(lastSession) {
            currentStreak = 0
        }
    }

    /// Formatted streak text
    var streakText: String {
        if currentStreak == 0 {
            return "Start your streak!"
        } else if currentStreak == 1 {
            return "1 day streak"
        } else {
            return "\(currentStreak) day streak"
        }
    }
}
