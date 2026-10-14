import Foundation
import Observation
import ReelsmithCore

/// The one object screens draw from and send actions to. It holds the `Editing` of Core: the state every
/// screen reads, and the history that undo and redo step through. With an open draft it writes the project
/// there after a change that ends no run, with the export choice and the undo history, synchronously.
///
/// https://developer.apple.com/documentation/observation/observable()
/// https://developer.apple.com/documentation/foundation/date
@MainActor @Observable
final class EditorStore {
    private(set) var editing: Editing
    var state: EditorState { editing.state }
    let mediaFolder: URL
    let options: LaunchOptions
    /// Nil for a seeded start without -drafts.
    let draft: OpenDraft?
    private(set) var exportSettings: ExportSettings

    /// `history` is the undo history the draft was written with. Nil reads as an empty history.
    init(
        state: EditorState, mediaFolder: URL, options: LaunchOptions, draft: OpenDraft? = nil,
        exportSettings: ExportSettings = .startChoice, history: UndoHistory? = nil
    ) {
        self.editing = Editing(state: state, history: history ?? UndoHistory())
        self.mediaFolder = mediaFolder
        self.options = options
        self.draft = draft
        self.exportSettings = exportSettings
    }

    func send(_ action: EditorAction) {
        editing = editing.after(action)
        if editing.writesNow {
            write()
        }
    }

    func undo() {
        editing = editing.undone()
        if editing.writesNow {
            write()
        }
    }

    func redo() {
        editing = editing.redone()
        if editing.writesNow {
            write()
        }
    }

    /// Writes the project without its blank texts, the export choice, the time and the history to the draft,
    /// whatever `unsaved` says. A throw is logged and leaves `unsaved` as it was, so the next write tries again.
    func write() {
        guard let draft else { return }
        let stored = Draft(
            project: editing.state.project.withoutBlankTexts, exportSettings: exportSettings, changed: Date(),
            history: editing.history)
        do {
            try draft.write(stored)
            editing = editing.written()
        } catch {
            NSLog("%@", "editor: the draft was not written: \(error)")
        }
    }

    /// Writes when something is not written yet, whatever the run.
    func writeNow() {
        if editing.unsaved {
            write()
        }
    }

    // slot: leave
    // end slot: leave

    // slot: export-choice
    /// Sets the export choice and writes the draft with it. The choice is no part of the history, so nothing
    /// is left unsaved and `writeNow` would write nothing.
    func choose(_ settings: ExportSettings) {
        exportSettings = settings
        write()
    }
    // end slot: export-choice
}
