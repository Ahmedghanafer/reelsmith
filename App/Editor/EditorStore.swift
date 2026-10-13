import Foundation
import Observation
import ReelsmithCore

/// The one object screens draw from and send actions to.
///
/// https://developer.apple.com/documentation/observation/observable()
@MainActor @Observable
final class EditorStore {
    private(set) var state: EditorState
    let mediaFolder: URL
    let options: LaunchOptions

    init(state: EditorState, mediaFolder: URL, options: LaunchOptions) {
        self.state = state
        self.mediaFolder = mediaFolder
        self.options = options
    }

    func send(_ action: EditorAction) {
        state = reduce(state, action)
    }
}
