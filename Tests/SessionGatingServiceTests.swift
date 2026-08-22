import XCTest
@testable import Verg

/// Unit tests for SessionGatingService
final class SessionGatingServiceTests: XCTestCase {

    // MARK: - Tests for Pure Gating Logic

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testCanViewPage_WhenPremium_AlwaysTrue() {
        let now = date(2026, 1, 20)
        XCTAssertTrue(SessionGatingService.canViewPage(isPremium: true, date: date(2026, 1, 20), now: now, calendar: utc))
        XCTAssertTrue(SessionGatingService.canViewPage(isPremium: true, date: date(2025, 1, 1), now: now, calendar: utc))
    }

    func testCanViewPage_WhenFree_WithinSevenDays_True() {
        let now = date(2026, 1, 20)
        XCTAssertTrue(SessionGatingService.canViewPage(isPremium: false, date: date(2026, 1, 20), now: now, calendar: utc))
        XCTAssertTrue(SessionGatingService.canViewPage(isPremium: false, date: date(2026, 1, 13), now: now, calendar: utc))
    }

    func testCanViewPage_WhenFree_OlderThanSevenDays_False() {
        let now = date(2026, 1, 20)
        XCTAssertFalse(SessionGatingService.canViewPage(isPremium: false, date: date(2026, 1, 12), now: now, calendar: utc))
        XCTAssertFalse(SessionGatingService.canViewPage(isPremium: false, date: date(2025, 6, 1), now: now, calendar: utc))
    }

    func testFreeArchiveWindow_IsSevenDays() {
        XCTAssertEqual(SessionGatingService.freeArchiveWindowDays, 7)
    }
}

// MARK: - AppStrings Tests

/// Unit tests for centralized copy strings
final class AppStringsTests: XCTestCase {

    func testOnboardingRitualSteps_HasFourSteps() {
        XCTAssertEqual(AppStrings.Onboarding.ritualSteps.count, 4)
    }

    func testOnboardingCommitmentOptions_IsThreeFiveSeven() {
        XCTAssertEqual(AppStrings.Onboarding.commitmentOptions, [3, 5, 7])
    }

    func testOnboardingWhatThisIsLine_IsOneLine() {
        XCTAssertFalse(AppStrings.Onboarding.whatThisIsLine.contains("\n"))
        XCTAssertFalse(AppStrings.Onboarding.whatThisIsLine.isEmpty)
    }

    func testStartTimerNotice_HasCorrectCopy() {
        XCTAssertEqual(AppStrings.CoachMark.StartTimer.title, "Start the timer")
        XCTAssertEqual(AppStrings.CoachMark.StartTimer.body, "Set your phone down. Write on paper while the candle burns.")
        XCTAssertEqual(AppStrings.CoachMark.StartTimer.primaryButton, "Start session")
    }

    func testUploadPhotoNotice_HasCorrectCopy() {
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.title, "Save your page")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.body, "Take a photo of what you wrote to keep your candle lit and archive.")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.primaryButton, "Upload photo")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.secondaryButton, "Skip")
    }

    func testSessionGatingLimit_IsOne() {
        XCTAssertEqual(AppStrings.SessionGating.freePhotoLimit, 1)
    }
}
