import Foundation
import Observation
import ReelsmithCore
import ReelsmithEngine

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
    /// Whether the preview shows the Instagram guide. Off at each open of an editor, never stored, no undo step.
    var showsGuide: Bool = false

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

    /// One step of a drag: with the steps before it in the same run one undo step. It writes nothing.
    func sendDragStep(_ action: EditorAction) {
        editing = editing.afterDragStep(action)
    }

    /// The end of a drag: the run ends, and the draft is written when something is not written yet.
    func endDrag() {
        editing = editing.endingRun()
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
    /// True when made. The root shows the start screen once it is false.
    private(set) var isOpen = true
    private var closing = false

    /// Writes the cover of the project's plan to the draft's cover file when the project has a clip, else
    /// removes that file. With no draft it does nothing. A throw is logged and leaves the file as it was.
    ///
    /// https://developer.apple.com/documentation/foundation/filemanager/fileexists(atpath:)
    /// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
    func makeCover() async {
        guard let draft else { return }
        let project: Project = editing.state.project
        guard !project.clips.isEmpty else {
            if FileManager.default.fileExists(atPath: draft.coverFile.path) {
                do {
                    try FileManager.default.removeItem(at: draft.coverFile)
                } catch {
                    NSLog("%@", "editor: the cover was not removed: \(error)")
                }
            }
            return
        }
        do {
            let plan = try renderPlan(for: project)
            try await writeCover(plan: plan, media: project.media, mediaFolder: mediaFolder, to: draft.coverFile)
        } catch {
            NSLog("%@", "editor: the cover was not written: \(error)")
        }
    }

    /// Writes what is not written yet, makes the cover, then closes. A second call while one runs does nothing.
    func close() async {
        guard !closing else { return }
        closing = true
        writeNow()
        await makeCover()
        isOpen = false
    }
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
