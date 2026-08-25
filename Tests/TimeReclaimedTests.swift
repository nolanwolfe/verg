import XCTest
import UIKit
@testable import Verg

/// Unit tests for the "Time Reclaimed" aggregation logic and the edge cases
/// called out in the feature spec: backgrounding, +5-min extension,
/// timezone/day-boundary correctness, and the confirmation copy rules.
final class TimeReclaimedAggregationTests: XCTestCase {

    private func session(daysAgo: Int, activeMinutes: Double, from now: Date = Date()) -> Session {
        Session(
            date: now.addingTimeInterval(-Double(daysAgo) * 86400),
            duration: activeMinutes * 60,
            activeDuration: activeMinutes * 60,
            imagePath: "x.jpg"
        )
    }

    func testSummary_BucketsToday_Week_AllTime() {
        let now = Date()
        let sessions = [
            session(daysAgo: 0, activeMinutes: 10, from: now),  // today
            session(daysAgo: 2, activeMinutes: 5, from: now),   // earlier this week (assuming not Sun/Mon)
            session(daysAgo: 10, activeMinutes: 20, from: now)  // weeks ago
        ]

        let summary = TimeReclaimed.summary(sessions: sessions, daysLit: 3, now: now)

        XCTAssertEqual(summary.todaySeconds, 600, accuracy: 1)
        XCTAssertEqual(summary.allTimeSeconds, 35 * 60, accuracy: 1)
        XCTAssertEqual(summary.daysLit, 3)
        // Week total includes at least today's session; exact week bucket
        // depends on which weekday `now` falls on, so just assert it's a
        // superset of today and doesn't include the 10-day-old session.
        XCTAssertGreaterThanOrEqual(summary.weekSeconds, summary.todaySeconds)
        XCTAssertLessThan(summary.weekSeconds, summary.allTimeSeconds)
    }

    func testSummary_EmptySessions_IsAllZero() {
        let summary = TimeReclaimed.summary(sessions: [], daysLit: 0)
        XCTAssertEqual(summary, .zero)
    }

    func testSummary_WeekBoundary_UsesCalendarWeekOfYear() {
        // Pin `now` to a known Wednesday so "this week" vs "last week" is
        // unambiguous regardless of when the suite runs.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 14, hour: 12))! // Wed

        let thisWeekSession = session(daysAgo: 1, activeMinutes: 10, from: now)   // Tue this week
        let lastWeekSession = session(daysAgo: 8, activeMinutes: 7, from: now)    // Tue last week

        let summary = TimeReclaimed.summary(
            sessions: [thisWeekSession, lastWeekSession],
            daysLit: 0,
            now: now,
            calendar: utc
        )

        XCTAssertEqual(summary.weekSeconds, 600, accuracy: 1)
        XCTAssertEqual(summary.lastWeekSeconds, 420, accuracy: 1)
        XCTAssertEqual(summary.weekDeltaMinutes, 3)
    }

    /// The spec requires day/week boundaries to track the device's current
    /// timezone rather than a hardcoded one. Same instant, two calendars
    /// with different time zones, different answers.
    func testSummary_DayBoundary_RespectsPassedCalendarTimeZone_NotHardcoded() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")! // UTC+9

        let now = utc.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 23, minute: 30))!
        // 10:00 UTC same day == 19:00 Jan 15 in Tokyo, i.e. still "yesterday"
        // relative to `now`'s Tokyo-local day (which started at 15:00 UTC).
        let borderlineSession = Session(
            date: utc.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10))!,
            duration: 300,
            activeDuration: 300,
            imagePath: "x.jpg"
        )

        let utcSummary = TimeReclaimed.summary(sessions: [borderlineSession], daysLit: 0, now: now, calendar: utc)
        let tokyoSummary = TimeReclaimed.summary(sessions: [borderlineSession], daysLit: 0, now: now, calendar: tokyo)

        XCTAssertEqual(utcSummary.todaySeconds, 300, "Counts as today under UTC")
        XCTAssertEqual(tokyoSummary.todaySeconds, 0, "Already yesterday under Tokyo's calendar day")
    }

    // MARK: - Confirmation copy

    func testConfirmationMessage_FirstSessionToday_UsesScrollingFraming() {
        let message = TimeReclaimed.confirmationMessage(todaySeconds: 12 * 60, isFirstSessionToday: true)
        XCTAssertEqual(message, "You wrote for 12 minutes instead of scrolling.")
    }

    func testConfirmationMessage_SecondSessionToday_ReportsRunningTotal_NoRepeat() {
        let message = TimeReclaimed.confirmationMessage(todaySeconds: 25 * 60, isFirstSessionToday: false)
        XCTAssertEqual(message, "You've written 25 minutes today.")
    }

    func testConfirmationMessage_LowNumber_IsNeutral_NoGuilt() {
        let message = TimeReclaimed.confirmationMessage(todaySeconds: 3 * 60, isFirstSessionToday: true)
        XCTAssertFalse(message.lowercased().contains("only"))
        XCTAssertFalse(message.lowercased().contains("just"))
        XCTAssertTrue(message.contains("3 minutes"))
    }

    func testConfirmationMessage_NeverReferencesScreenTimeOrEstimates() {
        for seconds in stride(from: 0.0, through: 3600, by: 137) {
            for isFirst in [true, false] {
                let message = TimeReclaimed.confirmationMessage(todaySeconds: seconds, isFirstSessionToday: isFirst).lowercased()
                XCTAssertFalse(message.contains("screen time"))
                XCTAssertFalse(message.contains("would have"))
                XCTAssertFalse(message.contains("instead of scrolling") && isFirst == false)
            }
        }
    }

    func testConfirmationMessage_SubMinuteSession_NeutralNoZero() {
        let message = TimeReclaimed.confirmationMessage(todaySeconds: 20, isFirstSessionToday: true)
        XCTAssertEqual(message, "You wrote for less than a minute today.")
    }

    // MARK: - Session-end card moment

    func testMoment_FirstSessionOfDay_ShowsTheSessionAndNoDayTotal() {
        // The card says "Your session", so the number is the session's own —
        // and on the first of the day the running total would only repeat it.
        let moment = TimeReclaimed.moment(sessionSeconds: 12 * 60, todaySeconds: 12 * 60, daysLit: 4)
        XCTAssertEqual(moment.minutes, 12)
        XCTAssertNil(moment.todayLine)
        XCTAssertEqual(moment.unit, "minutes")
        XCTAssertEqual(moment.daysLitLine, "4 days lit")
        XCTAssertEqual(moment.accessibleSentence,
                       "Your session: 12 minutes instead of scrolling. 4 days lit")
    }

    func testMoment_LaterSessionOfDay_ReportsSessionThenDayTotal() {
        // 24 minutes just now, 41 across the day. The headline number must be
        // the session, never the total — this is the case the old model got
        // wrong, showing the day's figure under a per-session heading.
        let moment = TimeReclaimed.moment(sessionSeconds: 24 * 60, todaySeconds: 41 * 60, daysLit: 2)
        XCTAssertEqual(moment.minutes, 24)
        XCTAssertEqual(moment.todayLine, "41 minutes today")
    }

    func testMoment_SingularMinute() {
        let moment = TimeReclaimed.moment(sessionSeconds: 60, todaySeconds: 60, daysLit: 1)
        XCTAssertEqual(moment.unit, "minute")
        // One day is a start, not yet a run: no emoji until two.
        XCTAssertEqual(moment.daysLitLine, "1 day lit")
    }

    func testMoment_UnlitCandle_HasNoDaysLitLine() {
        let moment = TimeReclaimed.moment(sessionSeconds: 10 * 60, todaySeconds: 10 * 60, daysLit: 0)
        XCTAssertNil(moment.daysLitLine)
    }

    func testMoment_SubMinute_ZeroMinutesWithNeutralCopy() {
        let moment = TimeReclaimed.moment(sessionSeconds: 20, todaySeconds: 20, daysLit: 0)
        XCTAssertEqual(moment.minutes, 0)
        XCTAssertEqual(moment.accessibleSentence, "Your session ran less than a minute.")
    }

    func testMoment_DayTotalEqualToSessionIsNotShownTwice() {
        // Rounding can make a later session's total match the session itself;
        // repeating the same figure under it would read as a bug.
        let moment = TimeReclaimed.moment(sessionSeconds: 30 * 60, todaySeconds: 30 * 60, daysLit: 3)
        XCTAssertNil(moment.todayLine)
    }
}

// MARK: - Session Codable

final class SessionActiveDurationCodingTests: XCTestCase {

    /// Sessions saved before 2.2 have no `activeDuration` key. Decoding
    /// must fall back to `duration` rather than crashing or defaulting to 0
    /// (which would make every legacy page look like it took no time).
    func testDecoding_LegacyJSONWithoutActiveDuration_FallsBackToDuration() throws {
        let legacyJSON = """
        {
            "id": "\(UUID().uuidString)",
            "date": 780000000,
            "duration": 600,
            "imagePath": "legacy.jpg",
            "createdAt": 780000000
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(Session.self, from: legacyJSON)
        XCTAssertEqual(session.duration, 600)
        XCTAssertEqual(session.activeDuration, 600)
    }

    func testDecoding_CurrentJSONWithActiveDuration_UsesStoredValue() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "date": 780000000,
            "duration": 600,
            "activeDuration": 430,
            "imagePath": "current.jpg",
            "createdAt": 780000000
        }
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(Session.self, from: json)
        XCTAssertEqual(session.duration, 600)
        XCTAssertEqual(session.activeDuration, 430)
    }

    func testRoundTrip_EncodeThenDecode_PreservesActiveDuration() throws {
        let original = Session(duration: 900, activeDuration: 512, imagePath: "x.jpg")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.activeDuration, 512)
    }
}

// MARK: - TimerService foreground-only tracking

/// Exercises TimerService.activeDuration through real app-lifecycle
/// notifications rather than reaching into private state, since that's
/// exactly how the app itself drives it.
final class TimerServiceActiveDurationTests: XCTestCase {

    func testActiveDuration_AccumulatesWhileRunning() {
        let service = TimerService()
        service.start(duration: 60)
        Thread.sleep(forTimeInterval: 0.4)
        service.pause()

        XCTAssertEqual(service.activeDuration, 0.4, accuracy: 0.25)
    }

    /// The core "Time Reclaimed" guarantee: time spent backgrounded must
    /// not be counted, even though the candle countdown itself keeps
    /// burning by wall clock while backgrounded.
    func testActiveDuration_ExcludesTimeInBackground() {
        let service = TimerService()
        service.start(duration: 60)
        Thread.sleep(forTimeInterval: 0.3)

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.5) // must NOT be counted

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        Thread.sleep(forTimeInterval: 0.3)
        service.pause()

        // ~0.6s foreground total; the 0.5s backgrounded gap is excluded
        XCTAssertEqual(service.activeDuration, 0.6, accuracy: 0.3)
        XCTAssertLessThan(service.activeDuration, 0.9, "Backgrounded time leaked into activeDuration")
    }

    func testActiveDuration_ResetsOnNewSessionStart() {
        let service = TimerService()
        service.start(duration: 60)
        Thread.sleep(forTimeInterval: 0.3)
        service.stopTimer()
        XCTAssertGreaterThan(service.activeDuration, 0)

        service.start(duration: 60)
        XCTAssertEqual(service.activeDuration, 0, "A fresh session must not inherit the previous session's time")
    }

    /// "+5 more minutes" after the candle burns out must resume tracking,
    /// not lose the extension's writing time.
    func testActiveDuration_RelightViaAddTime_ResumesTracking() {
        let service = TimerService()
        service.start(duration: 0.2)

        let completed = expectation(description: "candle completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { completed.fulfill() }
        wait(for: [completed], timeout: 2.0)
        XCTAssertTrue(service.isComplete)

        let beforeRelight = service.activeDuration
        XCTAssertGreaterThan(beforeRelight, 0)

        service.addTime(30) // relight — the isComplete branch
        XCTAssertFalse(service.isComplete)
        XCTAssertTrue(service.isRunning)

        Thread.sleep(forTimeInterval: 0.3)
        service.pause()

        XCTAssertGreaterThan(service.activeDuration, beforeRelight, "Relight must resume foreground tracking")
    }

    func testActiveDuration_NaturalCompletion_StopsTrackingAtCompletion() {
        let service = TimerService()
        service.start(duration: 0.2)

        let completed = expectation(description: "timer completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { completed.fulfill() }
        wait(for: [completed], timeout: 2.0)

        XCTAssertTrue(service.isComplete)
        let durationAtCompletion = service.activeDuration
        XCTAssertGreaterThan(durationAtCompletion, 0)

        // Time passing after natural completion (candle already out) must
        // not keep accumulating.
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(service.activeDuration, durationAtCompletion, accuracy: 0.05)
    }
}

// MARK: - Duration formatting

/// The Write pill and the Settings row show the same setting and disagreed:
/// integer division made a one-second timer read "0 min" on the pill.
final class DurationFormattingTests: XCTestCase {

    private func settings(_ seconds: TimeInterval) -> AppSettings {
        AppSettings(timerDuration: seconds)
    }

    func testSubMinuteReadsInSeconds() {
        XCTAssertEqual(settings(1).shortFormattedDuration, "1 sec")
        XCTAssertEqual(settings(1).formattedDuration, "1 sec")
        XCTAssertEqual(settings(30).shortFormattedDuration, "30 sec")
    }

    func testWholeMinutes() {
        XCTAssertEqual(settings(600).shortFormattedDuration, "10 min")
        XCTAssertEqual(settings(600).formattedDuration, "10 minutes")
        XCTAssertEqual(settings(60).formattedDuration, "1 minute", "not '1 minutes'")
    }

    func testRemainderIsNotSilentlyDropped() {
        // Ninety seconds used to read as one minute on both.
        XCTAssertEqual(settings(90).shortFormattedDuration, "1m 30s")
        XCTAssertEqual(settings(90).formattedDuration, "1m 30s")
    }
}

// MARK: - UserStats invariants

final class UserStatsInvariantTests: XCTestCase {

    /// A longest run shorter than the current one renders as "3, longest 0".
    /// Stored data can carry that: the key was `longestStreak` before the
    /// rename, and CandleService writes `daysLit` on its own.
    func testDecodingClampsLongestToAtLeastCurrent() throws {
        // Wire names are the pre-rename ones — see UserStats.CodingKeys.
        let json = #"{"currentStreak": 6, "longestStreak": 2, "totalSessions": 6}"#
        let stats = try JSONDecoder().decode(UserStats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.daysLit, 6)
        XCTAssertEqual(stats.longestDaysLit, 6, "longest must never trail current")
    }

    func testDecodingLeavesAHealthyLongestAlone() throws {
        let json = #"{"currentStreak": 2, "longestStreak": 9, "totalSessions": 20}"#
        let stats = try JSONDecoder().decode(UserStats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.longestDaysLit, 9)
    }
}
