import ReelsmithCore
import XCTest

final class EditActionsTests: XCTestCase {
    private let blue = ClipID(1)
    private let red = ClipID(2)
    private let green = ClipID(3)
    private let empty = EditorState(project: Seed.empty.project)
    private let threeClips = EditorState(project: Seed.threeClips.project)

    private func seedAt(_ playhead: Int64) -> EditorState {
        var state = threeClips
        state.playhead = Time(ticks: playhead)
        return state
    }

    private func playing(_ state: EditorState) -> EditorState {
        var next = state
        next.isPlaying = true
        return next
    }

    private func lengths(_ state: EditorState) -> [Int64] {
        state.project.clips.map { $0.duration.ticks }
    }

    private func ids(_ state: EditorState) -> [Int] {
        state.project.clips.map { $0.id.raw }
    }

    private func clip(_ id: ClipID, in state: EditorState) -> Clip? {
        state.project.clips.first { $0.id == id }
    }

    private func assertValid(_ state: EditorState, _ step: String, line: UInt = #line) {
        for clip in state.project.clips {
            let source = state.project.media[clip.media]?.duration ?? Time(ticks: -1)
            XCTAssertGreaterThanOrEqual(clip.sourceStart, Time.zero, step, line: line)
            XCTAssertLessThanOrEqual(clip.sourceStart + clip.duration, source, step, line: line)
            XCTAssertEqual(clip.duration.ticks % Time.frame.ticks, 0, step, line: line)
            XCTAssertGreaterThanOrEqual(clip.duration, TimelineGeometry.minimumClip, step, line: line)
        }
        XCTAssertEqual(state.playhead.ticks % Time.frame.ticks, 0, step, line: line)
        XCTAssertGreaterThanOrEqual(state.playhead, Time.zero, step, line: line)
        XCTAssertLessThanOrEqual(state.playhead, state.project.duration, step, line: line)
        if let selection = state.selection {
            XCTAssertNotNil(state.project.position(of: selection), step, line: line)
        }
    }

    func testEveryActionReturnsAValidStateFromAValidState() {
        let actions: [EditorAction] = [
            .addClips([TestClip.turned.info, TestClip.fast.info]),
            .movePlayhead(Time(ticks: 600)),
            .split,
            .select(ClipID(2)),
            .trimEnd(ClipID(2), by: Time(ticks: 5000)),
            .trimEnd(ClipID(2), by: Time(ticks: -619)),
            .trimStart(ClipID(2), by: Time(ticks: 619)),
            .trimStart(ClipID(2), by: Time(ticks: -5000)),
            .play,
            .movePlayhead(Time(ticks: 99999)),
            .trimStart(ClipID(5), by: Time(ticks: 5000)),
            .pause,
            .deleteSelected,
            .select(ClipID(5)),
            .deleteSelected,
            .clearSelection,
            .split,
        ]
        var state = threeClips
        assertValid(state, "seed")
        for (index, action) in actions.enumerated() {
            state = reduce(state, action)
            assertValid(state, "after action \(index): \(action)")
        }
    }

    func testTheFiveEditsLeaveIsPlayingFalse() {
        var playing = seedAt(600)
        playing.selection = red
        playing.isPlaying = true

        XCTAssertFalse(reduce(playing, .addClips([TestClip.turned.info])).isPlaying)
        XCTAssertFalse(reduce(playing, .split).isPlaying)
        XCTAssertFalse(reduce(playing, .trimStart(red, by: Time(ticks: 600))).isPlaying)
        XCTAssertFalse(reduce(playing, .trimEnd(red, by: Time(ticks: 600))).isPlaying)
        XCTAssertFalse(reduce(playing, .deleteSelected).isPlaying)
    }

    func testAnEditThatIsDoneButChangesNothingStillPauses() {
        let state = playing(threeClips)

        XCTAssertFalse(reduce(state, .addClips([])).isPlaying)
        XCTAssertFalse(reduce(state, .trimStart(red, by: Time(ticks: 19))).isPlaying)
    }

    func testAddClipsWithOtherFactsForAMediaInUseKeepsTheStateValid() {
        var shorter = TestClip.red.info
        shorter.duration = Time(ticks: 1200)

        let next = reduce(threeClips, .addClips([shorter]))

        assertValid(next, "red again with a shorter length")
        XCTAssertEqual(ids(next), [1, 2, 3, 4])
        XCTAssertEqual(lengths(next), [1800, 2400, 1200, 2400])
        XCTAssertEqual(next.project.media[TestClip.red.info.id], TestClip.red.info)
    }

    func testAddClipsTakesAMediaOfExactlyTheShortestLength() {
        var info = TestClip.turned.info
        info.duration = TimelineGeometry.minimumClip

        XCTAssertEqual(lengths(reduce(empty, .addClips([info]))), [60])
    }

    func testAddClipsStoresTheGivenFactsOfAMediaNoClipUsesAnyMore() {
        var state = reduce(empty, .addClips([TestClip.red.info]))
        state.selection = ClipID(1)
        state = reduce(state, .deleteSelected)
        var shorter = TestClip.red.info
        shorter.duration = Time(ticks: 1200)

        let next = reduce(state, .addClips([shorter]))

        XCTAssertEqual(lengths(next), [1200])
        XCTAssertEqual(next.project.media[shorter.id], shorter)
    }

    func testAddClipsOnTheEmptySeedPutsBlueThenRedAtTheEnd() {
        let next = reduce(empty, .addClips([TestClip.blue.info, TestClip.red.info]))

        XCTAssertEqual(next.project.duration, Time(ticks: 4200))
        XCTAssertEqual(ids(next), [1, 2])
        XCTAssertEqual(next.project.clips.map { $0.media }, [TestClip.blue.info.id, TestClip.red.info.id])
        XCTAssertEqual(next.project.clips.map { $0.sourceStart }, [Time.zero, Time.zero])
        XCTAssertEqual(next.project.media[TestClip.blue.info.id], TestClip.blue.info)
        XCTAssertEqual(next.project.media[TestClip.red.info.id], TestClip.red.info)
        XCTAssertEqual(next.project.nextClipID, 3)
        XCTAssertEqual(next.playhead, Time.zero)
        XCTAssertNil(next.selection)
    }

    func testAddClipsGoesToTheEndWithLengthsRoundedDownAndLeavesOutAMediaThatIsTooShort() {
        var long = TestClip.turned.info
        long.duration = Time(ticks: 1219)
        var short = TestClip.fast.info
        short.duration = Time(ticks: 59)

        let next = reduce(threeClips, .addClips([short, long]))

        XCTAssertEqual(ids(next), [1, 2, 3, 4])
        XCTAssertEqual(lengths(next), [1800, 2400, 1200, 1200])
        XCTAssertEqual(next.project.clips.last?.media, long.id)
        XCTAssertEqual(next.project.media[long.id], long)
        XCTAssertEqual(next.project.nextClipID, 5)
    }

    func testSplitCutsTheClipUnderThePlayheadInTwo() {
        var state = seedAt(600)
        state.selection = blue

        let next = reduce(state, .split)

        XCTAssertEqual(lengths(next), [600, 1200, 2400, 1200])
        XCTAssertEqual(ids(next), [1, 4, 2, 3])
        XCTAssertEqual(next.project.clips[1].media, next.project.clips[0].media)
        XCTAssertEqual(next.project.clips[0].sourceStart, Time.zero)
        XCTAssertEqual(next.project.clips[1].sourceStart, Time(ticks: 600))
        XCTAssertEqual(next.project.duration, Time(ticks: 5400))
        XCTAssertEqual(next.selection, blue)
        XCTAssertEqual(next.playhead, Time(ticks: 600))
        XCTAssertNil(reduce(seedAt(600), .split).selection)
    }

    func testTheTwoPartsOfASplitTouchInsideTheSourceOfATrimmedClip() {
        var state = reduce(threeClips, .trimStart(blue, by: Time(ticks: 600)))
        state.playhead = Time(ticks: 400)

        let next = reduce(state, .split)

        XCTAssertEqual(next.project.clips[0].sourceStart, Time(ticks: 600))
        XCTAssertEqual(next.project.clips[0].duration, Time(ticks: 400))
        XCTAssertEqual(next.project.clips[1].sourceStart, Time(ticks: 1000))
        XCTAssertEqual(next.project.clips[1].duration, Time(ticks: 800))
    }

    func testCanSplitNeedsTheShortestClipOnBothSidesOfThePlayhead() {
        XCTAssertTrue(seedAt(600).canSplit)
        XCTAssertTrue(seedAt(60).canSplit)
        XCTAssertFalse(seedAt(40).canSplit)
        XCTAssertTrue(seedAt(1740).canSplit)
        XCTAssertFalse(seedAt(1760).canSplit)
        XCTAssertTrue(seedAt(1860).canSplit)
    }

    func testCanSplitIsFalseOnAJoinAtTheEndAndOnAnEmptyProject() {
        XCTAssertFalse(seedAt(1800).canSplit)
        XCTAssertFalse(seedAt(5400).canSplit)
        XCTAssertFalse(empty.canSplit)
    }

    func testSplitThatCannotBeDoneReturnsTheStateUnchanged() {
        XCTAssertEqual(reduce(playing(seedAt(1800)), .split), playing(seedAt(1800)))
        XCTAssertEqual(reduce(playing(seedAt(40)), .split), playing(seedAt(40)))
        XCTAssertEqual(reduce(playing(seedAt(5400)), .split), playing(seedAt(5400)))
        XCTAssertEqual(reduce(empty, .split), empty)
    }

    func testTrimEndMovesTheLastFrameAndTheLaterClipsFollow() {
        let next = reduce(threeClips, .trimEnd(red, by: Time(ticks: 600)))

        XCTAssertEqual(clip(red, in: next)?.duration, Time(ticks: 1800))
        XCTAssertEqual(clip(red, in: next)?.sourceStart, Time.zero)
        XCTAssertEqual(next.project.duration, Time(ticks: 4800))
        XCTAssertEqual(next.project.start(of: green), Time(ticks: 3600))
    }

    func testTrimStartMovesTheFirstFrameAndTheLaterClipsFollow() {
        let next = reduce(threeClips, .trimStart(red, by: Time(ticks: 600)))

        XCTAssertEqual(clip(red, in: next)?.sourceStart, Time(ticks: 600))
        XCTAssertEqual(clip(red, in: next)?.duration, Time(ticks: 1800))
        XCTAssertEqual(next.project.start(of: red), Time(ticks: 1800))
        XCTAssertEqual(next.project.start(of: green), Time(ticks: 3600))
    }

    func testANegativeAmountMakesTheClipLonger() {
        let shortEnd = reduce(threeClips, .trimEnd(red, by: Time(ticks: 1200)))
        let shortStart = reduce(threeClips, .trimStart(red, by: Time(ticks: 1200)))

        let longerEnd = reduce(shortEnd, .trimEnd(red, by: Time(ticks: -600)))
        let longerStart = reduce(shortStart, .trimStart(red, by: Time(ticks: -600)))

        XCTAssertEqual(clip(red, in: longerEnd)?.duration, Time(ticks: 1800))
        XCTAssertEqual(clip(red, in: longerStart)?.duration, Time(ticks: 1800))
        XCTAssertEqual(clip(red, in: longerStart)?.sourceStart, Time(ticks: 600))
    }

    func testATrimAmountIsRoundedTowardZeroToWholeFrames() {
        let shortEnd = reduce(threeClips, .trimEnd(red, by: Time(ticks: 1200)))
        let shortStart = reduce(threeClips, .trimStart(red, by: Time(ticks: 1200)))

        XCTAssertEqual(clip(red, in: reduce(threeClips, .trimEnd(red, by: Time(ticks: 619))))?.duration, Time(ticks: 1800))
        XCTAssertEqual(clip(red, in: reduce(threeClips, .trimStart(red, by: Time(ticks: 619))))?.duration, Time(ticks: 1800))
        XCTAssertEqual(clip(red, in: reduce(shortEnd, .trimEnd(red, by: Time(ticks: -619))))?.duration, Time(ticks: 1800))
        XCTAssertEqual(clip(red, in: reduce(shortStart, .trimStart(red, by: Time(ticks: -619))))?.duration, Time(ticks: 1800))
    }

    func testATrimOfAClipWhoseMediaHasNoFactsReturnsTheStateUnchanged() {
        var state = playing(threeClips)
        state.project.media[TestClip.red.info.id] = nil

        XCTAssertEqual(reduce(state, .trimStart(red, by: Time(ticks: 600))), state)
        XCTAssertEqual(reduce(state, .trimEnd(red, by: Time(ticks: 600))), state)
    }

    func testATrimOfAClipThatIsNotInTheProjectReturnsTheStateUnchanged() {
        let state = playing(threeClips)

        XCTAssertEqual(reduce(state, .trimStart(ClipID(99), by: Time(ticks: 600))), state)
        XCTAssertEqual(reduce(state, .trimEnd(ClipID(99), by: Time(ticks: 600))), state)
    }

    func testATrimOfAClipWhoseSourceIsNotWholeFramesKeepsItsLengthInWholeFrames() {
        var info = TestClip.turned.info
        info.duration = Time(ticks: 1219)
        let added = reduce(empty, .addClips([info]))

        let shorter = reduce(added, .trimEnd(ClipID(1), by: Time(ticks: 600)))
        let longer = reduce(shorter, .trimEnd(ClipID(1), by: Time(ticks: -5000)))

        XCTAssertEqual(lengths(shorter), [600])
        XCTAssertEqual(lengths(longer), [1200])
        assertValid(longer, "grown back to the end of a source of 1219 ticks")
    }

    func testATrimStopsAtItsLimit() {
        let endShort = reduce(threeClips, .trimEnd(red, by: Time(ticks: 5000)))
        let startShort = reduce(threeClips, .trimStart(red, by: Time(ticks: 5000)))
        let endLong = reduce(threeClips, .trimEnd(red, by: Time(ticks: -600)))
        let startLong = reduce(threeClips, .trimStart(red, by: Time(ticks: -600)))

        XCTAssertEqual(clip(red, in: endShort)?.duration, Time(ticks: 60))
        XCTAssertEqual(clip(red, in: startShort)?.duration, Time(ticks: 60))
        XCTAssertEqual(clip(red, in: startShort)?.sourceStart, Time(ticks: 2340))
        XCTAssertEqual(clip(red, in: endLong)?.duration, Time(ticks: 2400))
        XCTAssertEqual(clip(red, in: startLong), clip(red, in: threeClips))
    }

    func testAfterATrimTheSelectionIsUnchangedAndThePlayheadStaysOrMovesToTheEnd() {
        var early = seedAt(600)
        early.selection = green
        var late = seedAt(5400)
        late.selection = green

        let earlyNext = reduce(early, .trimEnd(red, by: Time(ticks: 600)))
        let lateNext = reduce(late, .trimEnd(red, by: Time(ticks: 600)))
        let lateStart = reduce(late, .trimStart(red, by: Time(ticks: 600)))

        XCTAssertEqual(earlyNext.selection, green)
        XCTAssertEqual(earlyNext.playhead, Time(ticks: 600))
        XCTAssertEqual(lateNext.selection, green)
        XCTAssertEqual(lateNext.playhead, Time(ticks: 4800))
        XCTAssertEqual(lateStart.selection, green)
        XCTAssertEqual(lateStart.playhead, Time(ticks: 4800))
    }

    func testDeleteSelectedRemovesTheClipAndClearsTheSelection() {
        var state = seedAt(600)
        state.selection = green

        let next = reduce(state, .deleteSelected)

        XCTAssertEqual(next.project.duration, Time(ticks: 4200))
        XCTAssertEqual(ids(next), [1, 2])
        XCTAssertNil(next.selection)
        XCTAssertEqual(next.playhead, Time(ticks: 600))
    }

    func testAfterADeleteTheLaterClipsCloseTheGapAndThePlayheadMovesToTheEnd() {
        var state = seedAt(5400)
        state.selection = blue

        let next = reduce(state, .deleteSelected)

        XCTAssertEqual(ids(next), [2, 3])
        XCTAssertEqual(next.project.start(of: red), Time.zero)
        XCTAssertEqual(next.project.start(of: green), Time(ticks: 2400))
        XCTAssertEqual(next.playhead, Time(ticks: 3600))
    }

    func testDeletingTheOnlyClipLeavesAnEmptyProjectWithThePlayheadAtZero() {
        var state = reduce(empty, .addClips([TestClip.blue.info]))
        state.selection = blue
        state.playhead = Time(ticks: 600)

        let next = reduce(state, .deleteSelected)

        XCTAssertTrue(next.project.clips.isEmpty)
        XCTAssertEqual(next.playhead, Time.zero)
        XCTAssertNil(next.selection)
    }

    func testDeleteWithNothingSelectedReturnsTheStateUnchanged() {
        XCTAssertEqual(reduce(playing(seedAt(600)), .deleteSelected), playing(seedAt(600)))
    }

    func testAfterADeleteThePlayheadKeepsItsTimeAndTheMediaFactsStay() {
        var state = seedAt(3000)
        state.selection = blue

        let next = reduce(state, .deleteSelected)

        XCTAssertEqual(next.playhead, Time(ticks: 3000))
        XCTAssertEqual(next.project.media[TestClip.blue.info.id], TestClip.blue.info)
    }

    func testCanDeleteIsTrueExactlyWhenAClipIsSelected() {
        var selected = threeClips
        selected.selection = red

        XCTAssertTrue(selected.canDelete)
        XCTAssertFalse(threeClips.canDelete)
        XCTAssertFalse(empty.canDelete)
    }
}
