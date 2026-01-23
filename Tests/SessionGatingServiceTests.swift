import XCTest
@testable import Verg

/// Unit tests for SessionGatingService
final class SessionGatingServiceTests: XCTestCase {

    // MARK: - Tests for Pure Gating Logic

    func testCanStartSession_WhenPremium_ReturnsTrue() {
        // Premium users can always start sessions, regardless of count
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: true, completedSessionCount: 0))
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: true, completedSessionCount: 1))
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: true, completedSessionCount: 2))
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: true, completedSessionCount: 3))
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: true, completedSessionCount: 100))
    }

    func testCanStartSession_WhenNotPremium_AllowsFirst3Sessions() {
        // Free users can start sessions 1, 2, and 3
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 0))  // Can start 1st
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 1))  // Can start 2nd
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 2))  // Can start 3rd
    }

    func testCanStartSession_WhenNotPremium_BlocksAfter3Sessions() {
        // Free users cannot start 4th session or later
        XCTAssertFalse(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 3))  // Cannot start 4th
        XCTAssertFalse(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 4))
        XCTAssertFalse(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 10))
    }

    func testFreeSessionsLimit_IsThree() {
        XCTAssertEqual(SessionGatingService.freeSessionsLimit, 3)
    }

    // MARK: - Edge Cases

    func testCanStartSession_WithNegativeCount_ReturnsTrue() {
        // Edge case: negative session count should still allow starting
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: -1))
    }

    func testCanStartSession_ExactlyAtLimit() {
        // At exactly 3 sessions (limit), free users should be blocked
        XCTAssertFalse(SessionGatingService.canStartSession(isPremium: false, completedSessionCount: 3))
        // But premium users should not be blocked
        XCTAssertTrue(SessionGatingService.canStartSession(isPremium: true, completedSessionCount: 3))
    }
}

// MARK: - AppStrings Tests

/// Unit tests for centralized copy strings
final class AppStringsTests: XCTestCase {

    func testOnboardingPages_HasThreePages() {
        XCTAssertEqual(AppStrings.Onboarding.pages.count, 3)
    }

    func testOnboardingPage1_HasCorrectCopy() {
        let page = AppStrings.Onboarding.pages[0]
        XCTAssertEqual(page.title, "One simple ritual")
        XCTAssertEqual(page.subtitle, "Track your pages. Watch your progress and thoughts grow.")
        XCTAssertEqual(page.buttonText, "Begin")
    }

    func testOnboardingPage2_HasCorrectCopy() {
        let page = AppStrings.Onboarding.pages[1]
        XCTAssertEqual(page.title, "Not typing. Writing.")
        XCTAssertEqual(page.subtitle, "Grab a pen and paper.")
        XCTAssertEqual(page.buttonText, "I'm ready")
    }

    func testOnboardingPage3_HasCorrectCopy() {
        let page = AppStrings.Onboarding.pages[2]
        XCTAssertEqual(page.title, "Your thoughts need quiet")
        XCTAssertEqual(page.subtitle, "Put the phone down. Write like you mean it.")
        XCTAssertEqual(page.buttonText, "Start my first session")
    }

    func testSetTimerNotice_HasCorrectCopy() {
        XCTAssertEqual(AppStrings.CoachMark.SetTimer.title, "Set the timer")
        XCTAssertEqual(AppStrings.CoachMark.SetTimer.body, "Choose your session length, then start. Keep the phone down until it ends.")
        XCTAssertEqual(AppStrings.CoachMark.SetTimer.primaryButton, "Got it")
    }

    func testUploadPhotoNotice_HasCorrectCopy() {
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.title, "Save your page")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.body, "Snap a photo of what you wrote. It helps you track your streak and pages.")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.primaryButton, "Upload photo")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.secondaryButton, "Not now")
    }

    func testSessionGatingLimit_IsThree() {
        XCTAssertEqual(AppStrings.SessionGating.freeSessionsLimit, 3)
    }
}
