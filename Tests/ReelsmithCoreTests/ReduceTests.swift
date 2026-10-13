import ReelsmithCore
import XCTest

final class ReduceTests: XCTestCase {
    private let twoClips = EditorState(project: Seed.twoClips.project)

    func testSelectOfAClipOfTheProjectSetsTheSelection() {
        XCTAssertEqual(reduce(twoClips, .select(ClipID(2))).selection, ClipID(2))
    }

    func testSelectOfAnUnknownIdReturnsTheStateUnchanged() {
        var state = twoClips
        state.selection = ClipID(1)

        XCTAssertEqual(reduce(state, .select(ClipID(9))), state)
    }

    func testClearSelectionEmptiesIt() {
        var state = twoClips
        state.selection = ClipID(1)

        XCTAssertNil(reduce(state, .clearSelection).selection)
    }

    func testMovePlayheadRoundsDownToAFrameAndStaysInsideTheProject() {
        XCTAssertEqual(reduce(twoClips, .movePlayhead(Time(ticks: 4205))).playhead, Time(ticks: 4200))
        XCTAssertEqual(reduce(twoClips, .movePlayhead(Time(ticks: -40))).playhead, Time(ticks: 0))
        XCTAssertEqual(reduce(twoClips, .movePlayhead(Time(ticks: 9999))).playhead, Time(ticks: 4200))
        XCTAssertEqual(reduce(twoClips, .movePlayhead(Time(ticks: 1239))).playhead, Time(ticks: 1220))
    }

    func testMovePlayheadLeavesIsPlayingAlone() {
        var playing = twoClips
        playing.isPlaying = true

        XCTAssertTrue(reduce(playing, .movePlayhead(Time(ticks: 600))).isPlaying)
        XCTAssertFalse(reduce(twoClips, .movePlayhead(Time(ticks: 600))).isPlaying)
    }

    func testPlaySetsIsPlayingAndKeepsThePlayhead() {
        var state = twoClips
        state.playhead = Time(ticks: 600)

        let next = reduce(state, .play)

        XCTAssertTrue(next.isPlaying)
        XCTAssertEqual(next.playhead, Time(ticks: 600))
    }

    func testPlayAtTheEndStartsFromZero() {
        var state = twoClips
        state.playhead = Time(ticks: 4200)

        let next = reduce(state, .play)

        XCTAssertTrue(next.isPlaying)
        XCTAssertEqual(next.playhead, Time.zero)
    }

    func testPlayDoesNothingOnAnEmptyProject() {
        let empty = EditorState(project: Seed.empty.project)

        XCTAssertEqual(reduce(empty, .play), empty)
    }

    func testPauseClearsIsPlaying() {
        var state = twoClips
        state.isPlaying = true

        XCTAssertFalse(reduce(state, .pause).isPlaying)
    }
}
