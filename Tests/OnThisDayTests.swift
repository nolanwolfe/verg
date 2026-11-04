import XCTest
@testable import Verg

/// "On this day": which old page the journal offers back.
final class OnThisDayTests: XCTestCase {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 21) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func page(_ when: Date) -> Session {
        Session(date: when, duration: 600, imagePath: "x.jpg", createdAt: when)
    }

    func testNothingWrittenIsNoMatch() {
        XCTAssertNil(OnThisDay.find(in: [], today: date(2026, 11, 4), calendar: utc))
    }

    func testOneYearAgoToday() {
        let old = page(date(2025, 11, 4))
        let match = OnThisDay.find(in: [old, page(date(2026, 11, 1))], today: date(2026, 11, 4), calendar: utc)
        XCTAssertEqual(match?.session.id, old.id)
        XCTAssertEqual(match?.label, "One year ago today")
    }

    func testOldestAnniversaryWins() {
        let twoYears = page(date(2024, 11, 4))
        let oneYear = page(date(2025, 11, 4))
        let match = OnThisDay.find(in: [oneYear, twoYears], today: date(2026, 11, 4), calendar: utc)
        XCTAssertEqual(match?.session.id, twoYears.id)
        XCTAssertEqual(match?.label, "Two years ago today")
    }

    func testMonthIsTheFallback() {
        let lastMonth = page(date(2026, 10, 4))
        let match = OnThisDay.find(in: [lastMonth], today: date(2026, 11, 4), calendar: utc)
        XCTAssertEqual(match?.session.id, lastMonth.id)
        XCTAssertEqual(match?.label, "A month ago today")
    }

    func testOtherDaysDoNotMatch() {
        let pages = [page(date(2025, 11, 3)), page(date(2026, 10, 5)), page(date(2026, 11, 3))]
        XCTAssertNil(OnThisDay.find(in: pages, today: date(2026, 11, 4), calendar: utc))
    }

    func testFirstPageOfTheDayIsChosen() {
        let morning = page(date(2025, 11, 4, hour: 7))
        let night = page(date(2025, 11, 4, hour: 22))
        let match = OnThisDay.find(in: [night, morning], today: date(2026, 11, 4), calendar: utc)
        XCTAssertEqual(match?.session.id, morning.id)
    }

    /// Feb 29 has no anniversary in a common year; Feb 28 must not stand in.
    func testLeapDayDoesNotMatchTheTwentyEighth() {
        let leap = page(date(2024, 2, 29))
        XCTAssertNil(OnThisDay.find(in: [leap], today: date(2025, 2, 28), calendar: utc))
    }
}
