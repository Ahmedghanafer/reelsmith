import ReelsmithCore
import XCTest

final class CanvasTests: XCTestCase {
    private let wholeCanvas = Placement(quarterTurns: 0, x: 0, y: 0, width: 1920, height: 1080)

    /// The place of one clip alone in a project on the landscape canvas.
    private func placement(of info: MediaInfo) throws -> Placement {
        var project = Project(canvas: .landscape)
        project.media[info.id] = info
        project.clips = [Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: info.duration)]
        let plan = try renderPlan(for: project)
        XCTAssertEqual(plan.segments.count, 1)
        return try XCTUnwrap(plan.segments.first).placement
    }

    private func placement(width: Int, height: Int) throws -> Placement {
        try placement(of: MediaInfo(
            id: MediaID("one"), fileName: "one.mov", width: width, height: height, duration: Time(ticks: 600),
            quarterTurns: 0, hasSound: false))
    }

    func testTheTwoCanvasesAreLandscapeThenPortraitWithTheirSizes() {
        XCTAssertEqual(Canvas.allCases, [.landscape, .portrait])
        XCTAssertEqual(Canvas.landscape.width, 1920)
        XCTAssertEqual(Canvas.landscape.height, 1080)
        XCTAssertEqual(Canvas.portrait.width, 1080)
        XCTAssertEqual(Canvas.portrait.height, 1920)
        XCTAssertEqual(Canvas.startChoice, .landscape)
    }

    func testEachCanvasGivesItsWordKeyAndAllWordsListsTheTwo() {
        XCTAssertEqual(Canvas.landscape.words, Words("start.landscape"))
        XCTAssertEqual(Canvas.portrait.words, Words("start.portrait"))
        XCTAssertEqual(Canvas.allWords, ["start.landscape", "start.portrait"])
    }

    func testAProjectIsPortraitUnlessItIsGivenTheLandscapeCanvas() {
        let upright = Project()
        XCTAssertEqual(upright.canvas, .portrait)
        XCTAssertEqual(upright.clips, [])
        XCTAssertEqual(upright.nextClipID, 1)

        let wide = Project(canvas: .landscape)
        XCTAssertEqual(wide.canvas, .landscape)
        XCTAssertEqual(wide.clips, [])
        XCTAssertEqual(wide.nextClipID, 1)

        XCTAssertEqual(Project.framesPerSecond, 30)
    }

    func testThePlanCarriesTheCanvasOfTheProject() throws {
        XCTAssertEqual(try renderPlan(for: Seed.twoClipsWide.project).canvas, .landscape)
        XCTAssertEqual(try renderPlan(for: Seed.twoClips.project).canvas, .portrait)
        XCTAssertEqual(
            try renderPlan(for: Project(canvas: .landscape)),
            RenderPlan(segments: [], duration: .zero, canvas: .landscape))
        XCTAssertEqual(try renderPlan(for: Project()).canvas, .portrait)
    }

    func testAPlanWrittenWithNoCanvasIsPortrait() {
        XCTAssertEqual(RenderPlan(segments: [], duration: .zero).canvas, .portrait)
    }

    func testAWidePictureOfAnySizeFillsTheLandscapeCanvas() throws {
        XCTAssertEqual(try placement(width: 1920, height: 1080), wholeCanvas)
        XCTAssertEqual(try placement(width: 1280, height: 720), wholeCanvas)
        XCTAssertEqual(try placement(width: 3840, height: 2160), wholeCanvas)
    }

    func testAnUprightPictureStandsInTheMiddleOfTheLandscapeCanvas() throws {
        XCTAssertEqual(
            try placement(width: 1080, height: 1920),
            Placement(quarterTurns: 0, x: 656.25, y: 0, width: 607.5, height: 1080))
    }

    func testTheTurnedClipIsPlacedAsAnUprightPictureWithItsTurn() throws {
        XCTAssertEqual(TestClip.turned.storedWidth, 1920)
        XCTAssertEqual(TestClip.turned.storedHeight, 1080)
        XCTAssertEqual(
            try placement(of: TestClip.turned.info),
            Placement(quarterTurns: 1, x: 656.25, y: 0, width: 607.5, height: 1080))
    }

    func testASquarePictureStandsInTheMiddleOfTheLandscapeCanvas() throws {
        XCTAssertEqual(
            try placement(width: 1080, height: 1080),
            Placement(quarterTurns: 0, x: 420, y: 0, width: 1080, height: 1080))
    }

    func testTheSideThatLimitsTheFitIsExactlyTheSideOfTheLandscapeCanvas() throws {
        let fitted = try placement(width: 2532, height: 1170)

        XCTAssertEqual(fitted.width, 1920)
        XCTAssertEqual(fitted.x, 0)
    }

    func testTheWideSeedIsFoundByItsName() {
        XCTAssertEqual(Seed(rawValue: "two-clips-wide"), .twoClipsWide)
        XCTAssertEqual(LaunchOptions(arguments: ["-seed", "two-clips-wide"]).seed, .twoClipsWide)
    }

    func testTheWideSeedIsBlueThenRedOnTheLandscapeCanvas() throws {
        let seed = Seed.twoClipsWide
        XCTAssertEqual(seed.testClips, [.blue, .red])
        XCTAssertEqual(seed.canvas, .landscape)

        let project = seed.project
        XCTAssertEqual(project.clips.map(\.id), [ClipID(1), ClipID(2)])
        XCTAssertEqual(project.nextClipID, 3)
        XCTAssertEqual(project.duration, Time(ticks: 4200))
        XCTAssertEqual(project.canvas, .landscape)

        let plan = try renderPlan(for: project)
        XCTAssertEqual(
            plan.segments.map(\.placement),
            [wholeCanvas, Placement(quarterTurns: 0, x: 656.25, y: 0, width: 607.5, height: 1080)])
    }

    func testTheOtherThreeSeedsAreOnThePortraitCanvas() {
        for seed in [Seed.empty, Seed.twoClips, Seed.threeClips] {
            XCTAssertEqual(seed.canvas, .portrait, seed.rawValue)
            XCTAssertEqual(seed.project.canvas, .portrait, seed.rawValue)
        }
    }

    func testEveryEditKeepsTheCanvas() {
        var state = EditorState(project: Seed.twoClipsWide.project)
        XCTAssertEqual(state.project.canvas, .landscape)

        state = reduce(state, .addClips([TestClip.green.info]))
        XCTAssertEqual(state.project.clips.count, 3)
        XCTAssertEqual(state.project.canvas, .landscape, "after addClips")

        state = reduce(state, .movePlayhead(Time(ticks: 600)))
        state = reduce(state, .split)
        XCTAssertEqual(state.project.clips.count, 4)
        XCTAssertEqual(state.project.canvas, .landscape, "after split")

        state = reduce(state, .trimStart(ClipID(2), by: Time(ticks: 600)))
        XCTAssertEqual(state.project.duration, Time(ticks: 4800))
        XCTAssertEqual(state.project.canvas, .landscape, "after trimStart")

        state = reduce(state, .trimEnd(ClipID(2), by: Time(ticks: 600)))
        XCTAssertEqual(state.project.duration, Time(ticks: 4200))
        XCTAssertEqual(state.project.canvas, .landscape, "after trimEnd")

        for clip in state.project.clips {
            state = reduce(state, .select(clip.id))
            state = reduce(state, .deleteSelected)
            XCTAssertEqual(state.project.canvas, .landscape, "after deleteSelected")
        }
        XCTAssertEqual(state.project.clips, [])
        XCTAssertEqual(state.project.canvas, .landscape)
    }
}
