import XCTest
@testable import Verg

/// Days-lit milestone firing at each of the seven thresholds:
/// 7 / 14 / 30 / 50 / 75 / 100 / 150.
final class TerraceTests: XCTestCase {

    func testAllThresholds_MatchTheSpec() {
        XCTAssertEqual(Terrace.all.map(\.daysLitThreshold), [7, 14, 30, 50, 75, 100, 150])
    }

    func testAllTitles_ArePlainNumbers_NoTierNames() {
        let titles = Terrace.all.map(\.title)
        XCTAssertEqual(titles, [
            "Seven days lit.",
            "Fourteen days lit.",
            "Thirty days lit.",
            "Fifty days lit.",
            "Seventy-five days lit.",
            "One hundred days lit.",
            "One hundred and fifty days lit."
        ])
        for title in titles {
            XCTAssertFalse(title.lowercased().contains("terrace"))
            XCTAssertFalse(title.contains("!"))
        }
    }

    func testFiresAtEachThreshold() {
        for terrace in Terrace.all {
            let earned = Terrace.earnedThresholds(daysLit: terrace.daysLitThreshold)
            XCTAssertTrue(earned.contains(terrace.daysLitThreshold), "Should earn threshold \(terrace.daysLitThreshold) at exactly that day count")
        }
    }

    func testDoesNotFireOneDayBeforeThreshold() {
        for terrace in Terrace.all {
            let earned = Terrace.earnedThresholds(daysLit: terrace.daysLitThreshold - 1)
            XCTAssertFalse(earned.contains(terrace.daysLitThreshold), "Should not earn threshold \(terrace.daysLitThreshold) one day early")
        }
    }

    func testNewlyCrossed_ReturnsOnlyUnseenThresholds() {
        let unlocked: Set<Int> = [7, 14]
        let newly = Terrace.newlyCrossed(daysLit: 30, unlocked: unlocked)
        XCTAssertEqual(newly.map(\.daysLitThreshold), [30])
    }

    func testNewlyCrossed_MultipleAtOnce_AfterAGap() {
        // e.g. a relight/import bridges the user straight past two thresholds
        let newly = Terrace.newlyCrossed(daysLit: 30, unlocked: [])
        XCTAssertEqual(newly.map(\.daysLitThreshold), [7, 14, 30])
    }

    func testNextTerrace_AfterFinalThreshold_IsNil() {
        XCTAssertNil(Terrace.nextTerrace(after: 150))
        XCTAssertNil(Terrace.nextTerrace(after: 500))
    }

    func testNextTerrace_BetweenThresholds() {
        XCTAssertEqual(Terrace.nextTerrace(after: 40)?.daysLitThreshold, 50)
    }

    /// Volume/binding is deferred — crossing 150 should behave like any
    /// other threshold (fires once, plain-number copy), not crash or
    /// assume a binding flow exists.
    func testPassing150_FiresPlainMilestone_NoBindingAssumed() {
        let earned = Terrace.earnedThresholds(daysLit: 150)
        XCTAssertTrue(earned.contains(150))
        XCTAssertEqual(Terrace.all.last?.title, "One hundred and fifty days lit.")

        // Well past 150 — still just the same last milestone, no crash,
        // no further thresholds invented.
        let farPast = Terrace.earnedThresholds(daysLit: 400)
        XCTAssertEqual(farPast, Set(Terrace.all.map(\.daysLitThreshold)))
        XCTAssertNil(Terrace.nextTerrace(after: 400))
    }
}
