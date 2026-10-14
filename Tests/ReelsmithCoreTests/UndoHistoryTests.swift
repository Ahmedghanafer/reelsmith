import ReelsmithCore
import XCTest

final class UndoHistoryTests: XCTestCase {
    /// The editing a start on the seed begins with: its project, its selected text and its sound panel.
    private func start(_ seed: Seed) -> Editing {
        var state = EditorState(project: seed.project)
        state.selectedText = seed.selectedText
        state.showsSound = seed.showsSound
        return Editing(state: state)
    }

    private func sent(_ editing: Editing, _ actions: [EditorAction]) -> Editing {
        var next = editing
        for action in actions {
            next = next.after(action)
        }
        return next
    }

    private func move(_ x: Double) -> EditorAction {
        .text(.move(TextID(1), x: x, y: 100))
    }

    private func style(_ change: (inout TextStyle) -> Void, of editing: Editing) -> EditorAction {
        var style = editing.state.project.text(TextID(1))!.style
        change(&style)
        return .text(.setStyle(TextID(1), style))
    }

    func testADeleteIsUndoneAndRedone() {
        let deleted = sent(start(.twoClipsWide), [.select(ClipID(2)), .deleteSelected])
        XCTAssertEqual(deleted.state.project.clips.count, 1)
        XCTAssertTrue(deleted.canUndo)
        XCTAssertFalse(deleted.canRedo)

        let undone = deleted.undone()
        XCTAssertEqual(undone.state.project.clips, Seed.twoClipsWide.project.clips)
        XCTAssertTrue(undone.canRedo)
        XCTAssertFalse(undone.canUndo)

        let redone = undone.redone()
        XCTAssertEqual(redone.state.project.clips.map(\.id), [ClipID(1)])

        XCTAssertEqual(undone.undone(), undone)
        XCTAssertEqual(deleted.redone(), deleted)
    }

    func testEightTypedStringsAreOneStepAndWriteOnlyAfterTheRun() {
        let seedString = Seed.textWide.project.text(TextID(1))!.string
        var editing = start(.textWide)
        for count in 1...8 {
            editing = editing.after(.text(.setString(TextID(1), String("Hello wo".prefix(count)))))
            XCTAssertFalse(editing.writesNow)
        }
        XCTAssertEqual(editing.state.project.text(TextID(1))?.string, "Hello wo")
        XCTAssertEqual(editing.history.past.count, 1)
        XCTAssertEqual(editing.undone().state.project.text(TextID(1))?.string, seedString)

        editing = editing.after(.clearSelection)
        XCTAssertTrue(editing.writesNow)
        XCTAssertEqual(editing.history.past.count, 1)
    }

    func testEachGestureIsOneStep() {
        var editing = start(.textWide)
        editing = editing.after(.pause)
        editing = sent(editing, (1...20).map { move(100 + Double($0)) })
        XCTAssertEqual(editing.history.past.count, 1)

        editing = editing.after(.pause)
        editing = sent(editing, (1...20).map { move(300 + Double($0)) })
        XCTAssertEqual(editing.history.past.count, 2)

        editing = editing.after(.pause)
        for count in 1...10 {
            editing = editing.after(style({ $0.size = 70 + Double(count) }, of: editing))
        }
        XCTAssertEqual(editing.state.project.text(TextID(1))?.style.size, 80)
        XCTAssertEqual(editing.history.past.count, 3)

        editing = editing.after(.pause)
        editing = sent(editing, (1...10).map { move(500 + Double($0)) })
        editing = sent(editing, (1...10).map { .text(.turn(TextID(1), to: 10 + Double($0))) })
        XCTAssertEqual(editing.state.project.text(TextID(1))?.rotation, 20)
        XCTAssertEqual(editing.history.past.count, 4)
    }

    func testTwoTogglesAndAFontAreStepsOfTheirOwn() {
        var editing = start(.textWide)
        editing = editing.after(style({ $0.box = true }, of: editing))
        XCTAssertEqual(editing.history.past.count, 1)
        editing = editing.after(style({ $0.shadow = true }, of: editing))
        XCTAssertEqual(editing.history.past.count, 2)

        editing = editing.after(style({ $0.size = 80 }, of: editing))
        XCTAssertEqual(editing.history.past.count, 3)
        editing = editing.after(style({ $0.font = .naskhBold }, of: editing))
        XCTAssertEqual(editing.history.past.count, 4)
        editing = editing.after(style({ $0.size = 90 }, of: editing))
        XCTAssertEqual(editing.history.past.count, 5)

        XCTAssertEqual(editing.undone().undone().state.project.text(TextID(1))?.style.font, .naskh)
    }

    func testATextLeftBlankIsNoStepAndKeepsItsID() {
        var editing = start(.textWide)
        editing = sent(editing, [.text(.add), .clearSelection])
        XCTAssertFalse(editing.canUndo)
        XCTAssertFalse(editing.unsaved)
        XCTAssertEqual(editing.state.project.texts.map(\.id), [TextID(1)])
        XCTAssertEqual(editing.state.project.nextTextID, 3)

        editing = editing.after(.text(.add))
        XCTAssertEqual(editing.state.selectedText, TextID(3))
        XCTAssertEqual(editing.state.project.texts.map(\.id), [TextID(1), TextID(3)])

        let noSteps: [EditorAction] = [
            .movePlayhead(Time(ticks: 900)), .play, .pause, .select(ClipID(1)), .text(.select(TextID(1))),
            .sound(.open),
        ]
        editing = sent(editing, noSteps)
        XCTAssertFalse(editing.canUndo)
        XCTAssertFalse(editing.unsaved)

        let typed = sent(start(.textWide), [.text(.add), .text(.setString(TextID(2), "A"))])
        XCTAssertEqual(typed.history.past.count, 1)
        XCTAssertEqual(typed.state.project.texts.map(\.string).last, "A")
        XCTAssertEqual(typed.undone().state.project.texts, Seed.textWide.project.texts)
    }

    func testUndoAndRedoKeepOnlyWhatIsStillThere() {
        var editing = sent(start(.twoClipsWide), [.select(ClipID(2)), .deleteSelected, .select(ClipID(1)), .play])
        XCTAssertTrue(editing.state.isPlaying)
        editing = editing.undone()
        XCTAssertEqual(editing.state.project.clips.count, 2)
        XCTAssertEqual(editing.state.selection, ClipID(1))
        XCTAssertFalse(editing.state.isPlaying)

        editing = sent(editing, [.select(ClipID(2)), .play])
        editing = editing.redone()
        XCTAssertEqual(editing.state.project.clips.map(\.id), [ClipID(1)])
        XCTAssertNil(editing.state.selection)
        XCTAssertFalse(editing.state.isPlaying)

        editing = editing.undone()
        editing = editing.after(.movePlayhead(Time(ticks: 4000)))
        XCTAssertEqual(editing.state.playhead, Time(ticks: 4000))
        XCTAssertTrue(editing.canRedo)
        editing = editing.redone()
        XCTAssertEqual(editing.state.playhead, Time(ticks: 1800))

        var text = sent(start(.textWide), [.deleteSelected])
        XCTAssertEqual(text.state.project.texts, [])
        text = text.undone()
        XCTAssertEqual(text.state.project.texts, Seed.textWide.project.texts)
        text = sent(text, [.text(.select(TextID(1))), .play])
        text = text.redone()
        XCTAssertNil(text.state.selectedText)
        XCTAssertFalse(text.state.isPlaying)

        var empty = sent(
            start(.twoClipsWide), [.select(ClipID(2)), .deleteSelected, .select(ClipID(1)), .deleteSelected])
        XCTAssertEqual(empty.state.project.clips, [])
        empty = empty.undone().after(.sound(.open))
        XCTAssertTrue(empty.state.showsSound)
        empty = empty.undone()
        XCTAssertEqual(empty.state.project.clips.count, 2)
        XCTAssertTrue(empty.state.showsSound)
        empty = empty.redone().redone()
        XCTAssertEqual(empty.state.project.clips, [])
        XCTAssertFalse(empty.state.showsSound)
    }

    func testFiftyStepsAreKeptAndANewStepEndsTheFuture() {
        var editing = start(.twoClipsWide)
        for count in 1...51 {
            editing = editing.after(.sound(.setClipVolume(Double(count) / 100)))
        }
        XCTAssertEqual(UndoHistory.depth, 50)
        XCTAssertEqual(editing.history.past.count, 50)
        XCTAssertEqual(editing.history.past.first?.clipVolume, 1.0 / 100)
        XCTAssertEqual(editing.history.past.last?.clipVolume, 50.0 / 100)

        editing = editing.undone().undone()
        XCTAssertEqual(editing.history.future.count, 2)
        editing = editing.after(.sound(.muteClips(true)))
        XCTAssertEqual(editing.history.future, [])
        XCTAssertFalse(editing.canRedo)
        XCTAssertEqual(editing.history.past.count, 49)
    }

    func testUnsavedFollowsTheChangesAndTheWrites() {
        var editing = start(.twoClipsWide)
        XCTAssertFalse(editing.unsaved)
        editing = editing.after(.sound(.muteClips(true)))
        XCTAssertTrue(editing.unsaved)
        XCTAssertTrue(editing.writesNow)
        editing = editing.written()
        XCTAssertFalse(editing.unsaved)
        XCTAssertFalse(editing.writesNow)
        XCTAssertTrue(editing.canUndo)

        editing = editing.undone()
        XCTAssertTrue(editing.unsaved)
        editing = editing.written().redone()
        XCTAssertTrue(editing.unsaved)
        editing = editing.written()

        editing = sent(editing, [.movePlayhead(Time(ticks: 600)), .play, .pause, .select(ClipID(1))])
        XCTAssertFalse(editing.unsaved)
    }
}
