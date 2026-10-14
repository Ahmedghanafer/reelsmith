import Foundation
import Observation
import ReelsmithCore

/// The one object screens draw from and send actions to. It holds the `Editing` of Core: the state every
/// screen reads, and the history that undo and redo step through.
///
/// https://developer.apple.com/documentation/observation/observable()
@MainActor @Observable
final class EditorStore {
    private(set) var editing: Editing
    var state: EditorState { editing.state }
    let mediaFolder: URL
    let options: LaunchOptions

    init(state: EditorState, mediaFolder: URL, options: LaunchOptions) {
        self.editing = Editing(state: state)
        self.mediaFolder = mediaFolder
        self.options = options
    }

    func send(_ action: EditorAction) {
        editing = editing.after(action)
    }

    func undo() {
        editing = editing.undone()
    }

    func redo() {
        editing = editing.redone()
    }
}
