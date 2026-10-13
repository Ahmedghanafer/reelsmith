import ReelsmithCore
import XCTest

final class TimelineGeometryTests: XCTestCase {
    func testTheScaleAndTheShortestClip() {
        XCTAssertEqual(TimelineGeometry.pointsPerSecond, 60)
        XCTAssertEqual(TimelineGeometry.minimumClip, Time(ticks: 60))
    }

    func testXOfATime() {
        XCTAssertEqual(TimelineGeometry.x(of: Time(ticks: 1800)), 180)
    }

    func testWidthOfALength() {
        XCTAssertEqual(TimelineGeometry.width(of: Time(ticks: 2400)), 240)
    }

    func testTimeAtXRoundsDownToAFrameAndNeverGoesBelowZero() {
        XCTAssertEqual(TimelineGeometry.time(atX: 121), Time(ticks: 1200))
        XCTAssertEqual(TimelineGeometry.time(atX: -61), Time.zero)
    }

    func testTrimAmountIsWholeFramesRoundedTowardZero() {
        XCTAssertEqual(TimelineGeometry.trimAmount(forDragOf: 60), Time(ticks: 600))
        XCTAssertEqual(TimelineGeometry.trimAmount(forDragOf: -61), Time(ticks: -600))
    }
}
