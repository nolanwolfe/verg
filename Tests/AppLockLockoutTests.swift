import XCTest
@testable import Verg

/// The wrong-code lockout schedule. Pure functions only: the Keychain side
/// is exercised by the app-lock UI tests.
final class AppLockLockoutTests: XCTestCase {

    func testFirstFourWrongCodesAreFree() {
        for failures in 0...4 {
            XCTAssertEqual(AppLockService.lockoutDuration(afterFailures: failures), 0,
                           "Failure \(failures) should not lock entry")
        }
    }

    func testWaitClimbsThenCapsAtAnHour() {
        XCTAssertEqual(AppLockService.lockoutDuration(afterFailures: 5), 60)
        XCTAssertEqual(AppLockService.lockoutDuration(afterFailures: 6), 5 * 60)
        XCTAssertEqual(AppLockService.lockoutDuration(afterFailures: 7), 15 * 60)
        XCTAssertEqual(AppLockService.lockoutDuration(afterFailures: 8), 60 * 60)
        XCTAssertEqual(AppLockService.lockoutDuration(afterFailures: 500), 60 * 60)
    }

    func testWaitNeverShrinksAsFailuresGrow() {
        var previous: TimeInterval = 0
        for failures in 0...50 {
            let wait = AppLockService.lockoutDuration(afterFailures: failures)
            XCTAssertGreaterThanOrEqual(wait, previous)
            previous = wait
        }
    }

    /// The point of the schedule: guessing through all 10,000 four-digit
    /// codes has to take far longer than it did with no limit.
    func testExhaustingFourDigitCodesTakesMonths() {
        let total = (1...10_000).reduce(0.0) {
            $0 + AppLockService.lockoutDuration(afterFailures: $1)
        }
        XCTAssertGreaterThan(total, 365 * 24 * 60 * 60)
    }

    func testLockoutEndIsMeasuredFromTheLastFailure() {
        let last = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNil(AppLockService.lockoutEnd(failures: 4, lastFailure: last))
        XCTAssertEqual(AppLockService.lockoutEnd(failures: 5, lastFailure: last),
                       last.addingTimeInterval(60))
        XCTAssertEqual(AppLockService.lockoutEnd(failures: 9, lastFailure: last),
                       last.addingTimeInterval(3600))
    }

    func testLockoutMessage() {
        XCTAssertEqual(AppLockLockoutText.message(remaining: 59.2, biometryLabel: nil),
                       "Too many wrong codes. Try again in 1:00.")
        XCTAssertEqual(AppLockLockoutText.message(remaining: 3600, biometryLabel: "Face ID"),
                       "Too many wrong codes. Try again in 60:00. Face ID still works.")
        XCTAssertEqual(AppLockLockoutText.message(remaining: 0.1, biometryLabel: nil),
                       "Too many wrong codes. Try again in 0:01.")
    }
}
