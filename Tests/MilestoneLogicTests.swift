import XCTest
@testable import Verg

/// Tests for the pure milestone unlock logic.
/// NOTE: no test target is wired in the Xcode project yet — these follow the
/// convention of Tests/SessionGatingServiceTests.swift and also run as a
/// plain-swift harness (see scripts in the repo history).
final class MilestoneLogicTests: XCTestCase {

    func testThresholds() {
        XCTAssertEqual(Milestone.all.map(\.threshold), [10, 25, 50, 100, 250, 500, 1000])
    }

    func testNextMilestone() {
        XCTAssertEqual(Milestone.nextMilestone(after: 0)?.threshold, 10)
        XCTAssertEqual(Milestone.nextMilestone(after: 117)?.threshold, 250)
        XCTAssertNil(Milestone.nextMilestone(after: 1000))
    }

    func testBackfillForExistingUser() {
        XCTAssertEqual(Milestone.earnedThresholds(totalSessions: 117), [10, 25, 50, 100])
        XCTAssertEqual(Milestone.earnedThresholds(totalSessions: 0), [])
    }

    func testCrossingReturnsNewMilestone() {
        let crossed = Milestone.newlyCrossed(totalSessions: 10, unlocked: [])
        XCTAssertEqual(crossed.map(\.threshold), [10])
    }

    func testNoRecelebrationAfterBackfill() {
        let unlocked = Milestone.earnedThresholds(totalSessions: 117)
        XCTAssertTrue(Milestone.newlyCrossed(totalSessions: 118, unlocked: unlocked).isEmpty)
    }

    func testProgressTowardNext() {
        // 117 pages: between 100 and 250 → (117-100)/(250-100)
        XCTAssertEqual(Milestone.progress(totalSessions: 117), 17.0 / 150.0, accuracy: 0.0001)
        XCTAssertEqual(Milestone.progress(totalSessions: 1000), 1.0)
    }
}
