import Foundation

/// A weekly-goal-adherence milestone — separate track from the page-count
/// Milestone, celebrating consistency at whatever pace the user committed
/// to during onboarding rather than raw page volume. Additive: doesn't
/// touch page-count milestone thresholds or unlock state.
struct WeeklyGoalMilestone: Identifiable, Codable, Equatable {
    /// Threshold in completed weeks where the user met their chosen
    /// days-per-week commitment.
    let weeksThreshold: Int
    let title: String
    let icon: String

    var id: Int { weeksThreshold }
}

extension WeeklyGoalMilestone {
    static let all: [WeeklyGoalMilestone] = [
        WeeklyGoalMilestone(weeksThreshold: 1, title: "First Week", icon: "leaf.fill"),
        WeeklyGoalMilestone(weeksThreshold: 4, title: "One Month Strong", icon: "flame.fill"),
        WeeklyGoalMilestone(weeksThreshold: 12, title: "One Quarter", icon: "star.fill"),
        WeeklyGoalMilestone(weeksThreshold: 26, title: "Half a Year", icon: "crown.fill"),
        WeeklyGoalMilestone(weeksThreshold: 52, title: "A Full Year", icon: "trophy.fill")
    ]

    static func nextMilestone(after weeksMet: Int) -> WeeklyGoalMilestone? {
        all.first { $0.weeksThreshold > weeksMet }
    }

    static func earnedThresholds(weeksMet: Int) -> Set<Int> {
        Set(all.map(\.weeksThreshold).filter { $0 <= weeksMet })
    }

    static func newlyCrossed(weeksMet: Int, unlocked: Set<Int>) -> [WeeklyGoalMilestone] {
        all.filter { $0.weeksThreshold <= weeksMet && !unlocked.contains($0.weeksThreshold) }
    }
}

/// Pure, testable computation of how many *completed* calendar weeks (never
/// the current, still-in-progress one) had at least `goalDaysPerWeek`
/// distinct writing days.
enum WeeklyGoalTracker {
    static func weeksGoalMet(
        sessions: [Session],
        goalDaysPerWeek: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard goalDaysPerWeek > 0, !sessions.isEmpty else { return 0 }
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        var writingDaysByWeek: [Date: Set<Date>] = [:]
        for session in sessions {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start,
                  weekStart < currentWeekStart else { continue } // exclude the in-progress week
            let day = calendar.startOfDay(for: session.date)
            writingDaysByWeek[weekStart, default: []].insert(day)
        }

        return writingDaysByWeek.values.filter { $0.count >= goalDaysPerWeek }.count
    }
}
