import ReelsmithCore
import XCTest

final class ClipEditsTests: XCTestCase {
    private let blue = ClipID(1)
    private let red = ClipID(2)
    private let green = ClipID(3)

    private func order(_ state: EditorState) -> [String] {
        state.project.clips.map { $0.media.raw }
    }

    /// Three clips, playing, with the playhead at the time given.
    private func playing(at ticks: Int64, selected: ClipID? = nil) -> EditorState {
        var state = EditorState(project: Seed.threeClips.project)
        state.playhead = Time(ticks: ticks)
        state.selection = selected
        state.isPlaying = true
        return state
    }

    func testAMoveOfGreenToTheFirstPlaceSelectsItKeepsThePlayheadPausesAndUndoesInOneStep() {
        let start = playing(at: 600)

        let moved = reduce(start, .moveClip(green, to: 1))

        XCTAssertEqual(order(moved), ["green", "blue", "red"])
        XCTAssertEqual(moved.selection, green)
        XCTAssertEqual(moved.playhead, Time(ticks: 600))
        XCTAssertFalse(moved.isPlaying)

        let undone = Editing(state: start).after(.moveClip(green, to: 1)).undone()
        XCTAssertEqual(order(undone.state), ["blue", "red", "green"])
    }

    func testAMoveIsHeldBetweenTheFirstAndTheLastPlace() {
        let start = playing(at: 600)

        XCTAssertEqual(order(reduce(start, .moveClip(green, to: 0))), ["green", "blue", "red"])
        XCTAssertEqual(order(reduce(start, .moveClip(blue, to: 9))), ["red", "green", "blue"])
    }

    func testAMoveToItsOwnPlaceOfAnUnknownIdOrOnAnEmptyProjectReturnsTheStateUnchanged() {
        let start = playing(at: 600)
        var empty = EditorState(project: Seed.empty.project)
        empty.isPlaying = true

        XCTAssertEqual(reduce(start, .moveClip(red, to: 2)), start)
        XCTAssertEqual(reduce(start, .moveClip(ClipID(9), to: 1)), start)
        XCTAssertEqual(reduce(empty, .moveClip(blue, to: 1)), empty)
    }

    func testAMoveKeepsEveryTextItsRangeAndTheVolumeOfEachClip() {
        var start = playing(at: 600)
        start = reduce(start, .sound(.setVolumeOfClip(red, 0.4)))
        start.project.texts = [
            TextItem(
                id: TextID(1), string: "One", span: .range(TextRange(start: Time(ticks: 300), duration: Time(ticks: 900))),
                x: 540, y: 960, rotation: 0, style: .standard),
            TextItem(id: TextID(2), string: "Two", span: .whole, x: 540, y: 400, rotation: 0, style: .standard),
        ]
        start.project.nextTextID = 3

        let moved = reduce(start, .moveClip(green, to: 1))

        XCTAssertEqual(moved.project.texts, start.project.texts)
        XCTAssertEqual(moved.project.range(of: TextID(1)), start.project.range(of: TextID(1)))
        XCTAssertEqual(moved.project.range(of: TextID(2)), start.project.range(of: TextID(2)))
        XCTAssertEqual(moved.project.clips.map { $0.volume }, [1, 1, 0.4])
    }

    func testBothCutsAtSixHundredInsideBlue() {
        let start = playing(at: 600, selected: blue)
        XCTAssertTrue(start.canCutBefore)
        XCTAssertTrue(start.canCutAfter)

        let before = reduce(start, .cutBefore)
        XCTAssertEqual(before.project.clips[0], Clip(id: blue, media: MediaID("blue"), sourceStart: Time(ticks: 600), duration: Time(ticks: 1200)))
        XCTAssertEqual(before.playhead, Time.zero)
        XCTAssertEqual(before.selection, blue)
        XCTAssertFalse(before.isPlaying)

        let after = reduce(start, .cutAfter)
        XCTAssertEqual(after.project.clips[0], Clip(id: blue, media: MediaID("blue"), sourceStart: .zero, duration: Time(ticks: 600)))
        XCTAssertEqual(after.playhead, Time(ticks: 600))
        XCTAssertEqual(after.selection, blue)
        XCTAssertFalse(after.isPlaying)
    }

    func testNeitherCutNearTheEndsOfBlueInRedWithBlueSelectedOrWithNoSelection() {
        let states = [
            playing(at: 40, selected: blue), playing(at: 1760, selected: blue), playing(at: 2400, selected: blue),
            playing(at: 600),
        ]
        for state in states {
            XCTAssertFalse(state.canCutBefore, "playhead \(state.playhead.ticks)")
            XCTAssertFalse(state.canCutAfter, "playhead \(state.playhead.ticks)")
            XCTAssertEqual(reduce(state, .cutBefore), state, "playhead \(state.playhead.ticks)")
            XCTAssertEqual(reduce(state, .cutAfter), state, "playhead \(state.playhead.ticks)")
        }
    }

    func testBothCutsOfThePhotoOfPhotoWide() {
        let photo = ClipID(2)
        var start = EditorState(project: Seed.photoWide.project)
        start.selection = photo
        start.playhead = Time(ticks: 2400)
        start.isPlaying = true
        XCTAssertTrue(start.canCutBefore)
        XCTAssertTrue(start.canCutAfter)

        let before = reduce(start, .cutBefore)
        XCTAssertEqual(before.project.clips[1], Clip(id: photo, media: MediaID("magenta"), sourceStart: Time(ticks: 600), duration: Time(ticks: 1200)))
        XCTAssertEqual(before.playhead, Time(ticks: 1800))
        XCTAssertEqual(before.selection, photo)
        XCTAssertFalse(before.isPlaying)

        let after = reduce(start, .cutAfter)
        XCTAssertEqual(after.project.clips[1], Clip(id: photo, media: MediaID("magenta"), sourceStart: .zero, duration: Time(ticks: 600)))
        XCTAssertEqual(after.playhead, Time(ticks: 2400))
        XCTAssertEqual(after.selection, photo)
        XCTAssertFalse(after.isPlaying)
    }

    func testTheDropPositionOfRedAmongBlueAndGreen() {
        let project = Seed.threeClips.project

        XCTAssertEqual(project.dropPosition(of: red, at: Time(ticks: 0)), 1)
        XCTAssertEqual(project.dropPosition(of: red, at: Time(ticks: 800)), 1)
        XCTAssertEqual(project.dropPosition(of: red, at: Time(ticks: 1000)), 2)
        XCTAssertEqual(project.dropPosition(of: red, at: Time(ticks: 2500)), 3)
        XCTAssertNil(project.dropPosition(of: ClipID(9), at: Time(ticks: 800)))
    }

    func testTheClipPanelShowsForASelectedClipOnly() {
        let none = EditorState(project: Seed.threeClips.project)
        let selected = reduce(none, .select(blue))
        var text = EditorState(project: Seed.textWide.project)
        text.selectedText = Seed.textWide.selectedText

        XCTAssertTrue(selected.showsClipPanel)
        XCTAssertFalse(none.showsClipPanel)
        XCTAssertFalse(text.showsClipPanel)
        XCTAssertFalse(reduce(selected, .sound(.open)).showsClipPanel)
        XCTAssertFalse(reduce(selected, .deleteSelected).showsClipPanel)
    }

    func testTheVolumeOfTheClipShowsForABlueSelectedAndNotForThePhoto() {
        let blueSelected = reduce(EditorState(project: Seed.threeClips.project), .select(blue))
        let photoSelected = reduce(EditorState(project: Seed.photoWide.project), .select(ClipID(2)))

        XCTAssertTrue(blueSelected.showsClipVolume)
        XCTAssertTrue(photoSelected.showsClipPanel)
        XCTAssertFalse(photoSelected.showsClipVolume)
    }
}
