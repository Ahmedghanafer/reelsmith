import ReelsmithCore
import XCTest

final class TimeTests: XCTestCase {
    func testOneSecondIs600TicksAndOneFrameIs20() {
        XCTAssertEqual(Time(frames: 30, perSecond: 30).ticks, 600)
        XCTAssertEqual(Time.frame.ticks, 20)
    }

    func testFramesAreExactFor24And25And30And60() {
        XCTAssertEqual(Time(frames: 1, perSecond: 24).ticks, 25)
        XCTAssertEqual(Time(frames: 1, perSecond: 25).ticks, 24)
        XCTAssertEqual(Time(frames: 1, perSecond: 30).ticks, 20)
        XCTAssertEqual(Time(frames: 1, perSecond: 60).ticks, 10)
        XCTAssertEqual(Time(frames: 7, perSecond: 24).ticks, 175)
        XCTAssertEqual(Time(frames: 7, perSecond: 25).ticks, 168)
        XCTAssertEqual(Time(frames: 7, perSecond: 30).ticks, 140)
        XCTAssertEqual(Time(frames: 7, perSecond: 60).ticks, 70)
    }

    func testLessThanComparesByTicks() {
        XCTAssertTrue(Time(ticks: 1) < Time(ticks: 2))
        XCTAssertFalse(Time(ticks: 2) < Time(ticks: 1))
        XCTAssertFalse(Time(ticks: 2) < Time(ticks: 2))
    }

    func testMinusTakesTicksAway() {
        XCTAssertEqual(Time(ticks: 4200) - Time(ticks: 1800), Time(ticks: 2400))
    }

    func testRoundedDownToFrameTurns4199Into4180() {
        XCTAssertEqual(Time(ticks: 4199).roundedDownToFrame, Time(ticks: 4180))
    }

    func testClockTextReadsMinutesAndSecondsRoundedDown() {
        XCTAssertEqual(Time(ticks: 0).clockText, "00:00")
        XCTAssertEqual(Time(ticks: 4199).clockText, "00:06")
        XCTAssertEqual(Time(ticks: 4200).clockText, "00:07")
        XCTAssertEqual(Time(ticks: 36000).clockText, "01:00")
    }
}
