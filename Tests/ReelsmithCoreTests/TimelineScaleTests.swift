import ReelsmithCore
import XCTest

final class TimelineScaleTests: XCTestCase {
    func testTheStandardIsSixtyAndGivesWhatTheStaticFunctionsGive() {
        let standard = TimelineScale.standard
        XCTAssertEqual(standard.pointsPerSecond, 60)
        // The times and points of TimelineGeometryTests.swift.
        XCTAssertEqual(standard.x(of: Time(ticks: 1800)), TimelineGeometry.x(of: Time(ticks: 1800)))
        XCTAssertEqual(standard.width(of: Time(ticks: 2400)), TimelineGeometry.width(of: Time(ticks: 2400)))
        XCTAssertEqual(standard.time(atX: 121), TimelineGeometry.time(atX: 121))
        XCTAssertEqual(standard.time(atX: -61), TimelineGeometry.time(atX: -61))
        XCTAssertEqual(standard.trimAmount(forDragOf: 60), TimelineGeometry.trimAmount(forDragOf: 60))
        XCTAssertEqual(standard.trimAmount(forDragOf: -61), TimelineGeometry.trimAmount(forDragOf: -61))
    }

    func testAtOneHundredAndTwentyPointsASecond() {
        let scale = TimelineScale(pointsPerSecond: 120)
        XCTAssertEqual(scale.x(of: Time(ticks: 600)), 120)
        XCTAssertEqual(scale.trimAmount(forDragOf: -61), Time(ticks: -300))
    }

    func testAZoomIsHeldBetweenTenAndTwoHundredAndForty() {
        XCTAssertEqual(TimelineScale.least, 10)
        XCTAssertEqual(TimelineScale.most, 240)
        XCTAssertEqual(TimelineScale.standard.zoomed(by: 100).pointsPerSecond, 240)
        XCTAssertEqual(TimelineScale.standard.zoomed(by: 0.001).pointsPerSecond, 10)
    }

    func testAFactorThatIsNotAboveZeroOrNotFiniteGivesTheScaleUnchanged() {
        let scale = TimelineScale(pointsPerSecond: 120)
        for factor in [0, -1, Double.infinity, -Double.infinity, Double.nan] {
            XCTAssertEqual(scale.zoomed(by: factor), scale, String(factor))
        }
    }
}
