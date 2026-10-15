import Foundation
import ReelsmithCore
import XCTest

final class DragRunTests: XCTestCase {
    /// The editing of a start on music-wide with the video playing.
    private func playing() -> Editing {
        var state = EditorState(project: Seed.musicWide.project)
        state.showsSound = Seed.musicWide.showsSound
        return Editing(state: state).after(.play)
    }

    /// Drag steps of the volume of the clips, each followed by a report of the playhead as the player sends it
    /// while playing.
    private func dragged(_ editing: Editing, _ volumes: [Double], from tick: Int64) -> Editing {
        var next = editing
        for (index, volume) in volumes.enumerated() {
            next = next.afterDragStep(.sound(.setClipVolume(volume)))
            next = next.after(.movePlayhead(Time(ticks: tick + Int64(index + 1) * 20)))
        }
        return next
    }

    func testADragWhilePlayingIsOneStepAndWritesOnlyAtItsEnd() {
        let start = playing()
        XCTAssertTrue(start.state.isPlaying)
        var editing = dragged(start, [0.9, 0.8, 0.7], from: 0)
        XCTAssertEqual(editing.state.project.clipVolume, 0.7)
        XCTAssertEqual(editing.history.past.count, 1)
        XCTAssertTrue(editing.unsaved)
        XCTAssertFalse(editing.writesNow)

        editing = editing.endingRun()
        XCTAssertTrue(editing.writesNow)
        XCTAssertEqual(editing.history.past.count, 1)
        XCTAssertEqual(editing.undone().state.project.clipVolume, 1)

        editing = dragged(editing.written(), [0.6, 0.5], from: 100).endingRun()
        XCTAssertEqual(editing.history.past.count, 2)
        XCTAssertEqual(editing.history.past.last?.clipVolume, 0.7)
    }

    func testAChangeOfAnotherKindEndsTheRunAndNoChangeLeavesItOpen() {
        let open = playing().afterDragStep(.sound(.setClipVolume(0.5)))
        XCTAssertEqual(open.history.run, .drag)

        let selected = open.after(.select(ClipID(1))).after(.movePlayhead(Time(ticks: 300)))
        XCTAssertEqual(selected.history.run, .drag)
        XCTAssertFalse(selected.writesNow)

        let muted = open.after(.sound(.muteClips(true)))
        XCTAssertNil(muted.history.run)
        XCTAssertEqual(muted.history.past.count, 2)
        XCTAssertTrue(muted.writesNow)

        XCTAssertNil(open.undone().history.run)
        let again = open.undone().redone()
        XCTAssertNil(again.history.run)

        // A level sent by after(_:) is a step of its own, also during a drag run.
        let sent = open.after(.sound(.setClipVolume(0.4)))
        XCTAssertNil(sent.history.run)
        XCTAssertEqual(sent.history.past.count, 2)
    }

    func testADraftWithAnOpenDragRunRoundTripsAndOpensWithNoRun() throws {
        let editing = playing().afterDragStep(.sound(.setClipVolume(0.5)))
        XCTAssertEqual(editing.history.run, .drag)
        let draft = Draft(
            project: editing.state.project, exportSettings: .startChoice, changed: Date(timeIntervalSince1970: 0),
            history: editing.history)
        let back = try decodeDraft(try encodeDraft(draft))
        XCTAssertEqual(back, draft)
        XCTAssertEqual(back.history?.run, .drag)

        let opened = Editing(state: EditorState(project: back.project), history: try XCTUnwrap(back.history))
        XCTAssertNil(opened.history.run)
        XCTAssertEqual(opened.history.past, editing.history.past)
    }
}
