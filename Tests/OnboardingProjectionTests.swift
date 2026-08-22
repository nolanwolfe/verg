import XCTest
@testable import Verg

/// Unit tests for the onboarding projection screen's arithmetic. Computed,
/// not hardcoded — these tests exist so a change to `weeksPerYear` or
/// `minutesPerSession` can't silently drift the numbers shown to new users.
final class OnboardingProjectionTests: XCTestCase {

    func testCompute_FiveDaysPerWeek_MatchesWorkedExample() {
        // The brief's own worked example: 5 days/week → 260 pages, ~43 hours
        let result = OnboardingProjection.compute(daysPerWeek: 5)
        XCTAssertEqual(result.pages, 260)
        XCTAssertEqual(result.hours, 43.333, accuracy: 0.01)
        XCTAssertEqual(result.formattedHours, "43 hours")
    }

    func testCompute_ThreeDaysPerWeek() {
        let result = OnboardingProjection.compute(daysPerWeek: 3)
        XCTAssertEqual(result.pages, 156)
        XCTAssertEqual(result.hours, 26.0, accuracy: 0.01)
    }

    func testCompute_SevenDaysPerWeek() {
        let result = OnboardingProjection.compute(daysPerWeek: 7)
        XCTAssertEqual(result.pages, 364)
        XCTAssertEqual(result.hours, 60.667, accuracy: 0.01)
    }

    func testMinutesPerSession_MatchesAppDefaultTimerDuration() {
        // The projection must never silently diverge from the app's own
        // default session length.
        XCTAssertEqual(OnboardingProjection.minutesPerSession, AppSettings.defaultTimerDuration / 60)
    }

    func testFormattedHours_SingularVsPlural() {
        XCTAssertEqual(OnboardingProjection.Result(pages: 1, hours: 1.0).formattedHours, "1 hour")
        XCTAssertEqual(OnboardingProjection.Result(pages: 2, hours: 2.0).formattedHours, "2 hours")
    }

    func testCompute_ZeroDaysPerWeek_IsZero() {
        let result = OnboardingProjection.compute(daysPerWeek: 0)
        XCTAssertEqual(result.pages, 0)
        XCTAssertEqual(result.hours, 0)
    }
}

/// Unit tests for the weekly-goal-adherence computation backing the new
/// milestone track.
final class WeeklyGoalTrackerTests: XCTestCase {

    private func session(weeksAgo: Int, dayOffset: Int, from now: Date) -> Session {
        let date = Calendar.current.date(byAdding: .day, value: -(weeksAgo * 7) + dayOffset, to: now)!
        return Session(date: date, duration: 600, activeDuration: 600, imagePath: "x.jpg")
    }

    func testWeeksGoalMet_CountsOnlyCompletedWeeksMeetingGoal() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // Pin `now` to a known Wednesday so week boundaries are unambiguous.
        let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 12))!

        // Last week: wrote on 3 distinct days — meets a 3-day goal.
        let lastWeek = [
            session(weeksAgo: 1, dayOffset: 0, from: now),
            session(weeksAgo: 1, dayOffset: 1, from: now),
            session(weeksAgo: 1, dayOffset: 2, from: now)
        ]
        // Two weeks ago: only 1 day — misses a 3-day goal.
        let twoWeeksAgo = [session(weeksAgo: 2, dayOffset: 0, from: now)]
        // This (in-progress) week: 5 days — must NOT count, week isn't over.
        let thisWeek = (0..<5).map { session(weeksAgo: 0, dayOffset: -$0, from: now) }

        let weeksMet = WeeklyGoalTracker.weeksGoalMet(
            sessions: lastWeek + twoWeeksAgo + thisWeek,
            goalDaysPerWeek: 3,
            now: now,
            calendar: utc
        )

        XCTAssertEqual(weeksMet, 1)
    }

    func testWeeksGoalMet_MultipleSessionsSameDayCountOnce() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 12))!

        // Same day, 3 sessions — still only 1 distinct writing day.
        let sameDay = [
            session(weeksAgo: 1, dayOffset: 0, from: now),
            session(weeksAgo: 1, dayOffset: 0, from: now),
            session(weeksAgo: 1, dayOffset: 0, from: now)
        ]

        let weeksMet = WeeklyGoalTracker.weeksGoalMet(
            sessions: sameDay,
            goalDaysPerWeek: 2,
            now: now,
            calendar: utc
        )

        XCTAssertEqual(weeksMet, 0, "3 sessions on 1 day should not satisfy a 2-day goal")
    }

    func testWeeksGoalMet_EmptySessions_IsZero() {
        XCTAssertEqual(WeeklyGoalTracker.weeksGoalMet(sessions: [], goalDaysPerWeek: 5), 0)
    }

    func testWeeksGoalMet_ZeroGoal_IsZero() {
        let now = Date()
        let sessions = [session(weeksAgo: 1, dayOffset: 0, from: now)]
        XCTAssertEqual(WeeklyGoalTracker.weeksGoalMet(sessions: sessions, goalDaysPerWeek: 0), 0)
    }
}
