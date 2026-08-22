import XCTest
@testable import Verg

/// Unit tests for SessionGatingService
final class SessionGatingServiceTests: XCTestCase {

    // MARK: - Tests for Pure Gating Logic

    func testCanSavePhoto_WhenPremium_ReturnsTrue() {
        // Premium users can always save pages, regardless of count
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: true, completedPhotoCount: 0))
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: true, completedPhotoCount: 1))
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: true, completedPhotoCount: 2))
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: true, completedPhotoCount: 100))
    }

    func testCanSavePhoto_WhenNotPremium_AllowsFirstPhoto() {
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: false, completedPhotoCount: 0))
    }

    func testCanSavePhoto_WhenNotPremium_BlocksAfterFirstPhoto() {
        XCTAssertFalse(SessionGatingService.canSavePhoto(isPremium: false, completedPhotoCount: 1))
        XCTAssertFalse(SessionGatingService.canSavePhoto(isPremium: false, completedPhotoCount: 2))
        XCTAssertFalse(SessionGatingService.canSavePhoto(isPremium: false, completedPhotoCount: 10))
    }

    func testFreePhotoLimit_IsOne() {
        XCTAssertEqual(SessionGatingService.freePhotoLimit, 1)
    }

    // MARK: - Edge Cases

    func testCanSavePhoto_WithNegativeCount_ReturnsTrue() {
        // Edge case: negative photo count should still allow saving
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: false, completedPhotoCount: -1))
    }

    func testCanSavePhoto_ExactlyAtLimit() {
        // At exactly 1 saved photo (the limit), free users should be blocked
        XCTAssertFalse(SessionGatingService.canSavePhoto(isPremium: false, completedPhotoCount: 1))
        // But premium users should not be blocked
        XCTAssertTrue(SessionGatingService.canSavePhoto(isPremium: true, completedPhotoCount: 1))
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
        XCTAssertEqual(page.buttonText, "Leave the phone alone.")
    }

    func testOnboardingPage2_HasCorrectCopy() {
        let page = AppStrings.Onboarding.pages[1]
        XCTAssertEqual(page.title, "This app isn't for typing — it's for writing")
        XCTAssertEqual(page.subtitle, "Do you have a pen and paper?")
        XCTAssertEqual(page.buttonText, "I'm ready to write on paper")
    }

    func testOnboardingPage3_HasCorrectCopy() {
        let page = AppStrings.Onboarding.pages[2]
        XCTAssertEqual(page.title, "Your phone steals your thoughts")
        XCTAssertEqual(page.subtitle, "Endless attention. Zero reflection.")
        XCTAssertEqual(page.buttonText, "This is the door out.")
    }

    func testStartTimerNotice_HasCorrectCopy() {
        XCTAssertEqual(AppStrings.CoachMark.StartTimer.title, "Start the timer")
        XCTAssertEqual(AppStrings.CoachMark.StartTimer.body, "Set your phone down. Write on paper while the candle burns.")
        XCTAssertEqual(AppStrings.CoachMark.StartTimer.primaryButton, "Start session")
    }

    func testUploadPhotoNotice_HasCorrectCopy() {
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.title, "Save your page")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.body, "Take a photo of what you wrote to keep your streak and archive.")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.primaryButton, "Upload photo")
        XCTAssertEqual(AppStrings.CoachMark.UploadPhoto.secondaryButton, "Skip")
    }

    func testSessionGatingLimit_IsOne() {
        XCTAssertEqual(AppStrings.SessionGating.freePhotoLimit, 1)
    }
}
