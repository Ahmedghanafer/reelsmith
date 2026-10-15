import Foundation
import ReelsmithCore
import XCTest

/// Every sequence of four actions from a fixed menu, walked in order. Nothing is drawn at random.
final class UndoGuardTests: XCTestCase {
    private let menu: [EditorAction] = [
        .select(ClipID(1)),
        .deleteSelected,
        .trimEnd(ClipID(1), by: Time(ticks: 300)),
        .movePlayhead(Time(ticks: 900)),
        .split,
        .text(.setString(TextID(1), "A")),
        .text(.setString(TextID(1), "AB")),
        .text(.move(TextID(1), x: 100, y: 100)),
        .text(.add),
        .sound(.setClipVolume(0.5)),
        .sound(.muteClips(true)),
        .pause,
    ]

    /// Equal with nextTextID left out, as one step compares two projects.
    private func sameStep(_ a: Project, _ b: Project) -> Bool {
        var a = a
        a.nextTextID = b.nextTextID
        return a == b
    }

    func testEverySequenceOfFourIsUndoneAndRedoneWhole() {
        let began = Date()
        var state = EditorState(project: Seed.textWide.project)
        state.selectedText = Seed.textWide.selectedText
        state.showsSound = Seed.textWide.showsSound
        let first = Editing(state: state)
        let startProject = first.state.project.withoutBlankTexts
        var count = 0
        var failures = 0
        for a in menu {
            for b in menu {
                for c in menu {
                    for d in menu {
                        let sequence = [a, b, c, d]
                        var editing = first
                        for action in sequence {
                            editing = editing.after(action)
                        }
                        let end = editing.state.project.withoutBlankTexts
                        var undone = editing
                        while undone.canUndo {
                            undone = undone.undone()
                        }
                        var redone = undone
                        while redone.canRedo {
                            redone = redone.redone()
                        }
                        count += 1
                        let backAtStart = sameStep(undone.state.project.withoutBlankTexts, startProject)
                        let backAtEnd = redone.state.project.withoutBlankTexts == end
                        if !(backAtStart && backAtEnd) {
                            failures += 1
                            if failures <= 5 {
                                XCTFail(
                                    "sequence \(sequence): undone to the start \(backAtStart), "
                                        + "redone to the end \(backAtEnd)")
                            }
                        }
                    }
                }
            }
        }
        let seconds = Date().timeIntervalSince(began)
        print("Undo guard: \(count) sequences of four in \(seconds) seconds, \(failures) failed")
        XCTAssertEqual(count, 20736)
    }
}
