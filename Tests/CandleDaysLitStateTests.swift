import XCTest
@testable import Verg

/// Candle visual-state selection at each days-lit boundary: 6→7, 29→30,
/// 74→75. A candle well past 150 should hold at the richest state rather
/// than crash or invent a state that doesn't exist (Volume/reset isn't
/// built yet).
final class CandleDaysLitStateTests: XCTestCase {

    func testFreshState_ZeroToSix() {
        for days in 0...6 {
            XCTAssertEqual(CandleDaysLitState.forDaysLit(days), .fresh, "day \(days) should be fresh")
        }
    }

    func testSettlingState_SevenToTwentyNine() {
        XCTAssertEqual(CandleDaysLitState.forDaysLit(7), .settling)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(29), .settling)
    }

    func testEstablishedState_ThirtyToSeventyFour() {
        XCTAssertEqual(CandleDaysLitState.forDaysLit(30), .established)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(74), .established)
    }

    func testDeepState_SeventyFiveAndBeyond() {
        XCTAssertEqual(CandleDaysLitState.forDaysLit(75), .deep)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(150), .deep)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(400), .deep, "well past 150 should hold at the richest state, not crash or invent a new one")
    }

    func testBoundary_SixToSeven() {
        XCTAssertEqual(CandleDaysLitState.forDaysLit(6), .fresh)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(7), .settling)
    }

    func testBoundary_TwentyNineToThirty() {
        XCTAssertEqual(CandleDaysLitState.forDaysLit(29), .settling)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(30), .established)
    }

    func testBoundary_SeventyFourToSeventyFive() {
        XCTAssertEqual(CandleDaysLitState.forDaysLit(74), .established)
        XCTAssertEqual(CandleDaysLitState.forDaysLit(75), .deep)
    }

    func testHeightShrinksMonotonically() {
        let states: [CandleDaysLitState] = [.fresh, .settling, .established, .deep]
        let heights = states.map(\.maxHeight)
        XCTAssertEqual(heights, heights.sorted(by: >), "each state should be shorter than the last")
    }

    func testPoolGrowsMonotonically() {
        let states: [CandleDaysLitState] = [.fresh, .settling, .established, .deep]
        let pools = states.map(\.poolWidth)
        XCTAssertEqual(pools, pools.sorted(), "wax pooling should only grow with days lit")
        XCTAssertEqual(CandleDaysLitState.fresh.poolWidth, 0, "a fresh candle has no pooled wax")
    }

    func testFlameGrowsAndSteadiesMonotonically() {
        let states: [CandleDaysLitState] = [.fresh, .settling, .established, .deep]
        XCTAssertEqual(states.map(\.flameSizeMultiplier), states.map(\.flameSizeMultiplier).sorted())
        XCTAssertEqual(states.map(\.jitterMultiplier), states.map(\.jitterMultiplier).sorted(by: >), "higher days-lit states should flicker less, not more")
    }
}
