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

    // The writing of a text bar, on a screen from x 0 to x 402.

    func testTheWritingOfABarWhollyOnTheScreenIsSixPointsInsideBothEnds() {
        let writing = TimelineGeometry.writing(barX: 261, barWidth: 90, shownX: 0, shownWidth: 402)
        XCTAssertEqual(writing.x, 267)
        XCTAssertEqual(writing.width, 78)
    }

    func testTheWritingOfABarThatBeginsLeftOfTheScreenBeginsSixPointsInsideTheScreen() {
        // The bar ends at x 201.
        let writing = TimelineGeometry.writing(barX: -99, barWidth: 300, shownX: 0, shownWidth: 402)
        XCTAssertEqual(writing.x, 6)
        XCTAssertEqual(writing.width, 189)
    }

    func testTheWritingOfABarThatEndsRightOfTheScreenEndsSixPointsInsideTheScreen() {
        let writing = TimelineGeometry.writing(barX: 201, barWidth: 420, shownX: 0, shownWidth: 402)
        XCTAssertEqual(writing.x, 207)
        XCTAssertEqual(writing.width, 189)
    }

    func testTheWritingOfABarWiderThanTheScreenOnBothSidesIsSixPointsInsideTheScreen() {
        let writing = TimelineGeometry.writing(barX: -99, barWidth: 900, shownX: 0, shownWidth: 402)
        XCTAssertEqual(writing.x, 6)
        XCTAssertEqual(writing.width, 390)
        // A part of the row that does not begin at 0.
        let moved = TimelineGeometry.writing(barX: -99, barWidth: 900, shownX: 10, shownWidth: 402)
        XCTAssertEqual(moved.x, 16)
        XCTAssertEqual(moved.width, 390)
    }

    func testTheWritingHasNoWidthOffTheScreenAndBelowTwelvePoints() {
        // Right of the screen, left of it, the shortest bar, a bar of 11 points, 7 points of a bar on the screen.
        XCTAssertEqual(TimelineGeometry.writing(barX: 500, barWidth: 100, shownX: 0, shownWidth: 402).width, 0)
        XCTAssertEqual(TimelineGeometry.writing(barX: -200, barWidth: 100, shownX: 0, shownWidth: 402).width, 0)
        XCTAssertEqual(TimelineGeometry.writing(barX: 100, barWidth: 6, shownX: 0, shownWidth: 402).width, 0)
        XCTAssertEqual(TimelineGeometry.writing(barX: 100, barWidth: 11, shownX: 0, shownWidth: 402).width, 0)
        XCTAssertEqual(TimelineGeometry.writing(barX: 395, barWidth: 100, shownX: 0, shownWidth: 402).width, 0)
        // 13 points give 1.
        XCTAssertEqual(TimelineGeometry.writing(barX: 100, barWidth: 13, shownX: 0, shownWidth: 402).width, 1)
    }
}
