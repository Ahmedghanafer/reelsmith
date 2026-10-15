import Foundation
import ReelsmithCore
import XCTest

/// Holds the framing of a clip in the model, the plan and the edits, on the seed `two-clips`: a portrait canvas of
/// 1080 by 1920, blue (1920 by 1080, clip 1) then red (1080 by 1920, clip 2). Rectangles are pixels of the plan,
/// within 0.01, where a value is not compared whole.
final class FramingTests: XCTestCase {
    /// A draft of `two-clips` at 1080p and 30, as a draft of version 1 was written: no clip has `framing`.
    private let versionOne = #"{"changed":813704709,"exportSettings":{"rate":{"thirty":{}},"size":{"hd1080":{}}},"project":{"canvas":{"portrait":{}},"clipVolume":1,"clips":[{"duration":{"ticks":1800},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0},"volume":1},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0},"volume":1}],"clipsMuted":false,"media":[{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080},{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920}],"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}"#

    private let blue = ClipID(1)
    private let red = ClipID(2)

    /// `two-clips` with blue framed as given, not playing.
    private func seeded(blue framing: Framing = .standard) -> EditorState {
        var project = Seed.twoClips.project
        project.clips[0].framing = framing
        return EditorState(project: project)
    }

    private func playing(_ state: EditorState) -> EditorState {
        var state = state
        state.isPlaying = true
        return state
    }

    private func frame(_ state: EditorState, _ action: FrameAction) -> EditorState {
        reduce(state, .frame(action))
    }

    private func segments(_ state: EditorState, settings: ExportSettings = .standard) throws -> [Segment] {
        try renderPlan(for: state.project, settings: settings).segments
    }

    private func assertRect(
        _ placement: Placement?, _ x: Double, _ y: Double, _ width: Double, _ height: Double,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let placement else {
            XCTFail("no rectangle", file: file, line: line)
            return
        }
        XCTAssertEqual(placement.x, x, accuracy: 0.01, "x", file: file, line: line)
        XCTAssertEqual(placement.y, y, accuracy: 0.01, "y", file: file, line: line)
        XCTAssertEqual(placement.width, width, accuracy: 0.01, "width", file: file, line: line)
        XCTAssertEqual(placement.height, height, accuracy: 0.01, "height", file: file, line: line)
    }

    // Criterion 1.

    func testAVersionOneTextWhoseClipsLackFramingDecodesToTheStandardFraming() throws {
        let draft = try decodeDraft(Data(versionOne.utf8))

        XCTAssertEqual(draft.version, 1)
        XCTAssertEqual(draft.project, Seed.twoClips.project)
        XCTAssertEqual(draft.project.clips.map(\.framing), [Framing.standard, Framing.standard])
        XCTAssertEqual(Framing.standard, Framing(fit: .fit, backdrop: .black, zoom: 1, x: 0, y: 0))
    }

    func testADraftOfTwoClipsWithBlueFilledBlurredAndZoomedRoundTrips() throws {
        var project = Seed.twoClips.project
        project.clips[0].framing = Framing(fit: .fill, backdrop: .blurred, zoom: 1.5, x: 0.1)
        let draft = Draft(
            project: project, exportSettings: .startChoice, changed: Date(timeIntervalSince1970: 1_792_011_909))

        let back = try decodeDraft(try encodeDraft(draft))

        XCTAssertEqual(back, draft)
        XCTAssertEqual(back.project.clips[0].framing, Framing(fit: .fill, backdrop: .blurred, zoom: 1.5, x: 0.1, y: 0))
        XCTAssertEqual(back.project.clips[1].framing, .standard)
        XCTAssertEqual(back.version, 1)
    }

    // Criterion 2.

    func testThePlanOfTwoClipsAtTheStandardFramingIsTheFitOfToday() throws {
        let plan = try segments(seeded())

        XCTAssertEqual(plan.map(\.placement), [
            Placement(quarterTurns: 0, x: 0, y: 656.25, width: 1080, height: 607.5),
            Placement(quarterTurns: 0, x: 0, y: 0, width: 1080, height: 1920),
        ])
        XCTAssertEqual(plan.map(\.backdrop), [nil, nil])
    }

    // Criterion 3.

    func testFillCoversTheCanvasWithBlue() throws {
        let plan = try segments(seeded(blue: Framing(fit: .fill)))

        assertRect(plan[0].placement, -1166.67, 0, 3413.33, 1920)
        XCTAssertNil(plan[0].backdrop)
    }

    func testFitAtZoomTwoDoublesBlueAroundTheCentre() throws {
        let plan = try segments(seeded(blue: Framing(zoom: 2)))

        assertRect(plan[0].placement, -540, 352.5, 2160, 1215)
    }

    func testAnOffsetPastTheEdgeIsStoredHeld() throws {
        let zoomed = seeded(blue: Framing(zoom: 2))

        let right = frame(zoomed, .setOffset(blue, x: 0.6, y: 0))
        XCTAssertEqual(right.project.clips[0].framing.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(try segments(right)[0].placement.x, 0, accuracy: 0.01)

        let down = frame(zoomed, .setOffset(blue, x: 0, y: 0.3))
        XCTAssertEqual(down.project.clips[0].framing.y, 0.18359, accuracy: 0.0001)
        assertRect(try segments(down)[0].placement, -540, 705, 2160, 1215)

        let whole = frame(seeded(), .setOffset(blue, x: 0.2, y: 0))
        XCTAssertEqual(whole.project.clips[0].framing.x, 0)
    }

    func testABlurredBackdropFillsTheCanvasOnlyWhereThePictureLeavesBars() throws {
        var state = seeded(blue: Framing(backdrop: .blurred))
        state.project.clips[1].framing = Framing(backdrop: .blurred)

        let plan = try segments(state)

        assertRect(plan[0].placement, 0, 656.25, 1080, 607.5)
        assertRect(plan[0].backdrop, -1166.67, 0, 3413.33, 1920)
        XCTAssertNil(plan[1].backdrop)
    }

    func testThePlanAt4KHasEveryRectangleTwiceAsLarge() throws {
        var state = seeded(blue: Framing(backdrop: .blurred, zoom: 1.5, x: 0.05, y: -0.1))
        state.project.clips[1].framing = Framing(fit: .fill, zoom: 2, x: -0.2, y: 0.1)

        let standard = try segments(state)
        let large = try segments(state, settings: ExportSettings(size: .uhd4K, rate: .thirty))

        XCTAssertEqual(large.count, 2)
        for (big, small) in zip(large, standard) {
            let p = small.placement
            assertRect(big.placement, p.x * 2, p.y * 2, p.width * 2, p.height * 2)
        }
        let b = try XCTUnwrap(standard[0].backdrop)
        assertRect(large[0].backdrop, b.x * 2, b.y * 2, b.width * 2, b.height * 2)
        XCTAssertNil(large[1].backdrop)
    }

    // Criterion 4.

    func testEachFrameActionChangesOnlyTheNamedClipPausesAndIsOneUndoStep() throws {
        let start = playing(seeded())
        let actions: [(FrameAction, Framing)] = [
            (.setFit(blue, .fill), Framing(fit: .fill)),
            (.setBackdrop(blue, .blurred), Framing(backdrop: .blurred)),
            (.setZoom(blue, 2.5), Framing(zoom: 2.5)),
            (.setOffset(blue, x: 0, y: 0.25), Framing(y: 0.25)),
        ]
        for (action, framing) in actions {
            let after = frame(start, action)

            XCTAssertEqual(after.project.clips[0].framing, framing, "\(action)")
            XCTAssertEqual(after.project.clips[1], start.project.clips[1], "\(action)")
            XCTAssertFalse(after.isPlaying, "\(action)")

            let edited = Editing(state: start).after(.frame(action))
            XCTAssertEqual(edited.history.past.count, 1, "\(action)")
            XCTAssertEqual(edited.state.project, after.project, "\(action)")
            XCTAssertEqual(edited.undone().state.project, start.project, "\(action)")
        }
    }

    func testSetZoomHoldsItsValueAndTheOffsetAgain() {
        XCTAssertEqual(frame(seeded(blue: Framing(zoom: 2)), .setZoom(blue, 0.5)).project.clips[0].framing.zoom, 1)
        XCTAssertEqual(frame(seeded(), .setZoom(blue, 9)).project.clips[0].framing.zoom, 4)

        let moved = frame(seeded(blue: Framing(zoom: 2)), .setOffset(blue, x: 0.5, y: 0))
        XCTAssertEqual(moved.project.clips[0].framing.x, 0.5, accuracy: 0.0001)

        let back = frame(moved, .setZoom(blue, 1))
        XCTAssertEqual(back.project.clips[0].framing.zoom, 1)
        XCTAssertEqual(back.project.clips[0].framing.x, 0)
    }

    func testNothingChangesForAnUnknownIdOrAValueThatIsNotFinite() {
        let start = playing(seeded(blue: Framing(zoom: 2)))
        let unknown = ClipID(9)
        let refused: [FrameAction] = [
            .setFit(unknown, .fill), .setBackdrop(unknown, .blurred), .setZoom(unknown, 2),
            .setOffset(unknown, x: 0.1, y: 0.1), .applyToAll(unknown),
            .setZoom(blue, .nan), .setZoom(blue, .infinity),
            .setOffset(blue, x: .nan, y: 0.1), .setOffset(blue, x: 0.1, y: -.infinity),
        ]
        for action in refused {
            XCTAssertEqual(frame(start, action), start, "\(action)")
        }
    }

    // Criterion 5.

    func testApplyToAllGivesEveryClipTheFitAndBackdropAndKeepsTheirZoomAndOffset() throws {
        var start = seeded(blue: Framing(fit: .fill, backdrop: .blurred))
        start.project.clips[1].framing = Framing(zoom: 2, x: 0.3, y: -0.2)

        let edited = Editing(state: start).after(.frame(.applyToAll(blue)))
        let after = edited.state

        XCTAssertEqual(after.project.clips[0].framing, Framing(fit: .fill, backdrop: .blurred))
        XCTAssertEqual(after.project.clips[1].framing, Framing(fit: .fill, backdrop: .blurred, zoom: 2, x: 0.3, y: -0.2))
        XCTAssertEqual(edited.history.past.count, 1)
        XCTAssertEqual(edited.undone().state.project, start.project)
    }

    func testApplyToAllHoldsTheOffsetOfEachClipAgain() {
        var start = seeded(blue: Framing(fit: .fill, x: 0.3))
        start.project.clips[1].framing = Framing(backdrop: .blurred)

        let after = frame(start, .applyToAll(red))

        XCTAssertEqual(after.project.clips[0].framing, Framing(backdrop: .blurred))
        XCTAssertEqual(after.project.clips[1].framing, Framing(backdrop: .blurred))
    }

    // Criterion 6.

    func testASplitGivesBothHalvesTheFramingAndTheOtherEditsKeepIt() {
        let framing = Framing(fit: .fill, zoom: 1.5)
        var state = seeded(blue: framing)
        state.playhead = Time(ticks: 600)
        state.selection = blue

        let split = reduce(state, .split)
        XCTAssertEqual(split.project.clips.map(\.framing), [framing, framing, .standard])

        let moved = reduce(state, .moveClip(blue, to: 2))
        XCTAssertEqual(moved.project.clips.map(\.id), [red, blue])
        XCTAssertEqual(moved.project.clips[1].framing, framing)

        XCTAssertEqual(reduce(state, .cutBefore).project.clips[0].framing, framing)
        XCTAssertEqual(reduce(state, .cutAfter).project.clips[0].framing, framing)
        XCTAssertNotEqual(reduce(state, .cutBefore).project.clips[0].duration, state.project.clips[0].duration)
        XCTAssertNotEqual(reduce(state, .cutAfter).project.clips[0].duration, state.project.clips[0].duration)

        let added = reduce(state, .addClips([TestClip.green.info]))
        XCTAssertEqual(added.project.clips.count, 3)
        XCTAssertEqual(added.project.clips[2].framing, .standard)
    }

    // Criterion 7.

    func testFramedByHandIsTheSelectedClipUnderThePlayheadWithNoTextSelected() {
        var state = seeded()
        state.selection = blue
        state.playhead = Time(ticks: 600)
        XCTAssertEqual(state.framedByHand, blue)

        var text = state
        text.selectedText = TextID(1)
        XCTAssertNil(text.framedByHand)

        var none = state
        none.selection = nil
        XCTAssertNil(none.framedByHand)

        var other = state
        other.playhead = Time(ticks: 2400)
        XCTAssertNil(other.framedByHand)
    }

    func testFrameInfoReadsTheFramingOfTheSelectedClip() {
        var state = seeded()
        XCTAssertEqual(state.frameInfo, "none")

        state = reduce(state, .select(blue))
        XCTAssertEqual(state.frameInfo, "fit black 100 0,0")

        state = frame(state, .setFit(blue, .fill))
        state = frame(state, .setBackdrop(blue, .blurred))
        state = frame(state, .setZoom(blue, 1.5))
        state = frame(state, .setOffset(blue, x: 0.1, y: -0.05))
        let framing = state.project.clips[0].framing
        XCTAssertEqual(framing.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(framing.y, -0.05, accuracy: 0.0001)
        XCTAssertEqual(state.frameInfo, "fill blur 150 100,-50")
    }

    // Criterion 8.

    func testSameFootageHoldsBetweenProjectsThatDifferOnlyInAFraming() {
        let plain = Seed.twoClips.project
        var framed = plain
        framed.clips[1].framing = Framing(fit: .fill, backdrop: .blurred, zoom: 3, x: 0.1, y: 0.2)

        XCTAssertNotEqual(plain, framed)
        XCTAssertTrue(plain.sameFootage(as: framed))
        XCTAssertTrue(framed.sameFootage(as: plain))
    }
}
