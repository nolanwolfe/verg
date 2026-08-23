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

    func testOnboardingPitch_IsTwoSingleLines() {
        for line in [AppStrings.Onboarding.pitchHeadline, AppStrings.Onboarding.pitchSubline] {
            XCTAssertFalse(line.contains("\n"))
            XCTAssertFalse(line.isEmpty)
        }
    }

    /// VOICE.md §2.1: no exclamation marks, with one sanctioned exception
    /// in the share-sheet text. Onboarding is not it.
    func testOnboardingCopy_HasNoExclamationMarks() {
        let copy = [
            AppStrings.Onboarding.epigraphQuote,
            AppStrings.Onboarding.epigraphAttribution,
            AppStrings.Onboarding.pitchHeadline,
            AppStrings.Onboarding.pitchSubline,
            AppStrings.Onboarding.ritualTitle,
            AppStrings.Onboarding.commitmentTitle,
            AppStrings.Onboarding.commitmentSubtitle,
            AppStrings.Onboarding.projectionIntro,
            AppStrings.Onboarding.ratingPromptTitle,
            AppStrings.Onboarding.ratingPromptBody
        ] + AppStrings.Onboarding.ritualSteps.map(\.text)

        for line in copy {
            XCTAssertFalse(line.contains("!"), "Exclamation mark in onboarding copy: \(line)")
        }
    }

    func testRitualSteps_SayUntilTheBell_NotBurnsOut() {
        let texts = AppStrings.Onboarding.ritualSteps.map(\.text)
        XCTAssertTrue(texts.contains("Write until the bell"))
        // "burns out" is what a missed day means; the ritual rows must not
        // reuse it for a completed session.
        XCTAssertFalse(texts.contains { $0.lowercased().contains("burns out") })
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

// MARK: - Writing Prompt Tests

final class WritingPromptTests: XCTestCase {

    func testBuiltInPrompts_ExistAndAreShort() {
        XCTAssertFalse(WritingPrompt.builtIn.isEmpty)
        for prompt in WritingPrompt.builtIn {
            XCTAssertFalse(prompt.text.isEmpty)
            // A prompt is a door, not a paragraph.
            XCTAssertLessThanOrEqual(prompt.text.count, 60, "Prompt too long: \(prompt.text)")
            XCTAssertFalse(prompt.text.contains("!"), "Exclamation mark in prompt: \(prompt.text)")
        }
    }

    func testNext_EmptyPool_IsNil() {
        XCTAssertNil(WritingPrompt.next(from: [], after: nil))
    }

    func testNext_SinglePrompt_ReturnsItEvenIfCurrent() {
        let only = WritingPrompt(text: "Only one.")
        XCTAssertEqual(WritingPrompt.next(from: [only], after: only)?.id, only.id)
    }

    func testNext_NeverRepeatsCurrentWhenAlternativesExist() {
        let pool = (0..<5).map { WritingPrompt(text: "Prompt \($0)") }
        let current = pool[2]
        for _ in 0..<50 {
            let next = WritingPrompt.next(from: pool, after: current)
            XCTAssertNotNil(next)
            XCTAssertNotEqual(next?.id, current.id)
        }
    }

    func testNext_NoCurrent_ReturnsSomethingFromPool() {
        let pool = (0..<3).map { WritingPrompt(text: "Prompt \($0)") }
        let next = WritingPrompt.next(from: pool, after: nil)
        XCTAssertTrue(pool.contains { $0.id == next?.id })
    }
}
