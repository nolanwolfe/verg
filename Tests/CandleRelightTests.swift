import XCTest
@testable import Verg

/// Unit tests for the premium relight mechanic — one relight per rolling
/// 7 days bridges a missed day without extinguishing the candle. Free
/// users' candles always go out on a miss.
final class CandleRelightTests: XCTestCase {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Free users

    func testFreeUser_MissedDay_CandleGoesOut() {
        let last = date(2026, 1, 10)
        let today = date(2026, 1, 12) // missed the 11th
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 5, relitDates: [],
            isPremium: false, today: today, calendar: utc
        )
        XCTAssertTrue(result.candleWentOut)
        XCTAssertEqual(result.daysLit, 0)
        XCTAssertTrue(result.relitDates.isEmpty, "Free users never get relights")
    }

    func testFreeUser_WroteYesterday_CandleStaysLit() {
        let last = date(2026, 1, 10)
        let today = date(2026, 1, 11)
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 5, relitDates: [],
            isPremium: false, today: today, calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.daysLit, 5)
    }

    // MARK: - Premium: single isolated miss

    func testPremium_SingleMissedDay_Relit() {
        let last = date(2026, 1, 10)
        let today = date(2026, 1, 12) // missed the 11th
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 5, relitDates: [],
            isPremium: true, today: today, calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.daysLit, 5, "Relit days don't count as written")
        XCTAssertEqual(result.relitDates, [date(2026, 1, 11, hour: 0)])
    }

    /// "A miss on day one" — the very first day after ever writing.
    func testPremium_MissOnDayOne_Relit() {
        let last = date(2026, 1, 1)
        let today = date(2026, 1, 3) // missed Jan 2, the day right after starting
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 1, relitDates: [],
            isPremium: true, today: today, calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.daysLit, 1)
        XCTAssertEqual(result.relitDates.count, 1)
    }

    // MARK: - Consecutive misses

    func testPremium_ConsecutiveMisses_OnlyFirstDayRelit_CandleGoesOutOnSecond() {
        let last = date(2026, 1, 10)
        let today = date(2026, 1, 13) // missed both the 11th and 12th
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 5, relitDates: [],
            isPremium: true, today: today, calendar: utc
        )
        XCTAssertTrue(result.candleWentOut, "A relight used on day 1 of the gap can't also cover day 2")
        XCTAssertEqual(result.daysLit, 0)
        XCTAssertEqual(result.relitDates, [date(2026, 1, 11, hour: 0)], "The first gap day was still recorded as relit before the candle went out")
    }

    // MARK: - Two misses inside seven days

    func testPremium_TwoIsolatedMissesWithinSevenDays_SecondNotRelit() {
        // Miss on the 11th (relit), write on the 12th, then miss again on
        // the 15th — only 4 days after the first relight.
        var stats = CandleRelight.evaluate(
            lastSessionDate: date(2026, 1, 10), daysLit: 5, relitDates: [],
            isPremium: true, today: date(2026, 1, 12), calendar: utc
        )
        XCTAssertFalse(stats.candleWentOut)
        XCTAssertEqual(stats.relitDates.count, 1)

        // Simulate writing on the 12th (a real session), then evaluate the
        // next gap using the relitDates carried forward.
        stats = CandleRelight.evaluate(
            lastSessionDate: date(2026, 1, 12), daysLit: 6, relitDates: stats.relitDates,
            isPremium: true, today: date(2026, 1, 16), calendar: utc // missed the 15th
        )
        XCTAssertTrue(stats.candleWentOut, "Second miss within 7 days of the first relight must not get another one")
        XCTAssertEqual(stats.daysLit, 0)
    }

    func testPremium_SecondMissExactlySevenDaysLater_IsRelit() {
        // First relight applied for Jan 11. A second isolated miss on
        // Jan 18 is exactly 7 days later and should be eligible again.
        let result = CandleRelight.evaluate(
            lastSessionDate: date(2026, 1, 17), daysLit: 5, relitDates: [date(2026, 1, 11, hour: 0)],
            isPremium: true, today: date(2026, 1, 19), calendar: utc // missed the 18th
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.relitDates.count, 2)
    }

    // MARK: - Timezone changes

    func testTimezoneChange_EvaluationUsesPassedCalendar_NotHardcodedUTC() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")! // UTC+9

        // last session 11pm Jan 10 UTC == 8am Jan 11 Tokyo local
        let last = date(2026, 1, 10, hour: 23)
        // "today" 1am Jan 12 UTC == 10am Jan 12 Tokyo local — under UTC this
        // looks like a 1-day gap (missed the 11th); under Tokyo's calendar
        // the last session was already on the 11th, so there's no gap at all.
        let today = utc.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 1))!

        let utcResult = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 3, relitDates: [], isPremium: false, today: today, calendar: utc
        )
        let tokyoResult = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 3, relitDates: [], isPremium: false, today: today, calendar: tokyo
        )

        XCTAssertTrue(utcResult.candleWentOut, "Under UTC there's a missed day")
        XCTAssertFalse(tokyoResult.candleWentOut, "Under Tokyo's calendar day boundary there's no gap")
    }

    // MARK: - Month boundary

    func testMissSpanningMonthBoundary_RelitCorrectly() {
        let last = date(2026, 1, 31)
        let today = date(2026, 2, 2) // missed Feb 1
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 10, relitDates: [],
            isPremium: true, today: today, calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.relitDates, [date(2026, 2, 1, hour: 0)])
    }

    func testMissSpanningMonthBoundary_FreeUserCandleGoesOut() {
        let last = date(2026, 1, 31)
        let today = date(2026, 2, 2)
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 10, relitDates: [],
            isPremium: false, today: today, calendar: utc
        )
        XCTAssertTrue(result.candleWentOut)
    }

    // MARK: - Subscription lapses mid-week

    /// Relight eligibility is evaluated using CURRENT premium status at
    /// evaluation time, not historical status on the day of the miss — so
    /// a miss that happens while subscribed does NOT get bridged if the
    /// subscription has already lapsed by the time the gap is evaluated.
    func testSubscriptionLapsedBeforeEvaluation_MissNotRelit_EvenThoughOnceSubscribed() {
        let last = date(2026, 1, 10)
        let today = date(2026, 1, 12) // missed the 11th
        // isPremium: false represents "lapsed by the time this runs" —
        // CandleRelight has no notion of past entitlement, only current.
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 5, relitDates: [],
            isPremium: false, today: today, calendar: utc
        )
        XCTAssertTrue(result.candleWentOut)
    }

    /// If they're still premium when the gap is evaluated, a mid-week lapse
    /// that hasn't taken effect yet doesn't block the relight.
    func testStillPremiumAtEvaluation_MissIsRelit_RegardlessOfUpcomingLapse() {
        let last = date(2026, 1, 10)
        let today = date(2026, 1, 12)
        let result = CandleRelight.evaluate(
            lastSessionDate: last, daysLit: 5, relitDates: [],
            isPremium: true, today: today, calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
    }

    // MARK: - isRelightAvailable / isRelit helpers

    func testIsRelightAvailable_NoPriorRelights_True() {
        XCTAssertTrue(CandleRelight.isRelightAvailable(asOf: date(2026, 1, 15), relitDates: [], calendar: utc))
    }

    func testIsRelit_MatchesStartOfDayRegardlessOfTimeComponent() {
        let relit = [date(2026, 1, 11, hour: 0)]
        XCTAssertTrue(CandleRelight.isRelit(date(2026, 1, 11, hour: 18), relitDates: relit, calendar: utc))
        XCTAssertFalse(CandleRelight.isRelit(date(2026, 1, 12), relitDates: relit, calendar: utc))
    }

    // MARK: - No history

    func testNoLastSessionDate_NothingToEvaluate() {
        let result = CandleRelight.evaluate(
            lastSessionDate: nil, daysLit: 0, relitDates: [],
            isPremium: true, today: date(2026, 1, 12), calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.daysLit, 0)
    }

    func testWroteToday_NoGapToEvaluate() {
        let today = date(2026, 1, 12)
        let result = CandleRelight.evaluate(
            lastSessionDate: today, daysLit: 5, relitDates: [],
            isPremium: false, today: today, calendar: utc
        )
        XCTAssertFalse(result.candleWentOut)
        XCTAssertEqual(result.daysLit, 5)
    }
}
