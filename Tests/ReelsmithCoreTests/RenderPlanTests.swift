import ReelsmithCore
import XCTest

final class RenderPlanTests: XCTestCase {
    private let wholeCanvas = Placement(quarterTurns: 0, x: 0, y: 0, width: 1080, height: 1920)
    private let acrossTheMiddle = Placement(quarterTurns: 0, x: 0, y: 656.25, width: 1080, height: 607.5)

    private func placement(width: Int, height: Int, quarterTurns: Int) throws -> Placement {
        let info = MediaInfo(
            id: MediaID("one"), fileName: "one.mov", width: width, height: height, duration: Time(ticks: 600),
            quarterTurns: quarterTurns, hasSound: false)
        var project = Project()
        project.media[info.id] = info
        project.clips = [Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: info.duration)]
        let plan = try renderPlan(for: project)
        return try XCTUnwrap(plan.segments.first).placement
    }

    func testThreeClipsGiveThreeSegmentsInARow() throws {
        let plan = try renderPlan(for: Seed.threeClips.project)

        XCTAssertEqual(plan.segments.map(\.clip), [ClipID(1), ClipID(2), ClipID(3)])
        XCTAssertEqual(plan.segments.map(\.media), [MediaID("blue"), MediaID("red"), MediaID("green")])
        XCTAssertEqual(plan.segments.map(\.timelineStart.ticks), [0, 1800, 4200])
        XCTAssertEqual(plan.segments.map(\.duration.ticks), [1800, 2400, 1200])
        XCTAssertEqual(plan.segments.map(\.sourceStart.ticks), [0, 0, 0])
        XCTAssertEqual(plan.segments.map(\.hasSound), [true, true, false])
        XCTAssertEqual(plan.duration, Time(ticks: 5400))
    }

    func testAClipThatStartsInsideItsSourceGivesASegmentThatDoes() throws {
        var project = Seed.twoClips.project
        project.clips[0].sourceStart = Time(ticks: 600)

        let plan = try renderPlan(for: project)

        XCTAssertEqual(plan.segments.first?.sourceStart, Time(ticks: 600))
    }

    func testAnEmptyProjectGivesAnEmptyPlan() throws {
        XCTAssertEqual(try renderPlan(for: Seed.empty.project), RenderPlan(segments: [], duration: .zero))
    }

    func testAClipWithoutMediaFactsThrowsUnknownMedia() {
        var project = Seed.twoClips.project
        project.media[MediaID("red")] = nil

        XCTAssertThrowsError(try renderPlan(for: project)) { error in
            XCTAssertEqual(error as? PlanError, PlanError.unknownMedia(MediaID("red")))
        }
    }

    func testRedFillsTheCanvasAndBlueSitsAcrossTheMiddle() throws {
        let plan = try renderPlan(for: Seed.threeClips.project)

        XCTAssertEqual(plan.segments.map(\.placement), [acrossTheMiddle, wholeCanvas, wholeCanvas])
    }

    func testAQuarterTurnIsCountedBeforeTheFit() throws {
        let turned = TestClip.turned.info

        XCTAssertEqual(
            try placement(width: turned.width, height: turned.height, quarterTurns: turned.quarterTurns),
            Placement(quarterTurns: 1, x: 0, y: 0, width: 1080, height: 1920))
    }

    func testTwoQuarterTurnsSitAsBlueDoes() throws {
        XCTAssertEqual(
            try placement(width: 1920, height: 1080, quarterTurns: 2),
            Placement(quarterTurns: 2, x: 0, y: 656.25, width: 1080, height: 607.5))
    }

    func testTheSideThatLimitsTheFitIsExactlyTheCanvasSide() throws {
        let fitted = try placement(width: 1170, height: 2532, quarterTurns: 0)

        XCTAssertEqual(fitted.height, 1920)
        XCTAssertEqual(fitted.y, 0)
    }

    func testANarrowPictureIsCentredAndScaledByOneFactor() throws {
        XCTAssertEqual(
            try placement(width: 1080, height: 2160, quarterTurns: 0),
            Placement(quarterTurns: 0, x: 60, y: 0, width: 960, height: 1920))
    }

    func testThreeQuarterTurnsAreCountedBeforeTheFit() throws {
        XCTAssertEqual(
            try placement(width: 1920, height: 1080, quarterTurns: 3),
            Placement(quarterTurns: 3, x: 0, y: 0, width: 1080, height: 1920))
    }

    func testASmallPictureIsEnlargedToFillTheCanvas() throws {
        XCTAssertEqual(try placement(width: 540, height: 960, quarterTurns: 0), wholeCanvas)
    }
}
