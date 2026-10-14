import ReelsmithCore
import SwiftUI

/// The row of the two edit buttons and the text button. It decides nothing: Core says whether a button is enabled,
/// and a tap sends one action. A row of SwiftUI lays out from leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/button
/// https://developer.apple.com/documentation/swiftui/hstack
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
struct ToolsRow: View {
    let state: EditorState
    let send: @MainActor (EditorAction) -> Void

    var body: some View {
        HStack(spacing: 32) {
            Button("tools.split") { sendStill(.split) }
                .disabled(!state.canSplit)
                .accessibilityIdentifier("editor.split")
            Button("tools.delete") { sendStill(.deleteSelected) }
                .disabled(!state.canDelete)
                .accessibilityIdentifier("editor.delete")
            Button("tools.text") { sendStill(.text(.add)) }
                .disabled(!state.canAddText)
                .accessibilityIdentifier("editor.addText")
        }
    }

    /// Sends the action of a tap inside a transaction that disables animations, so a button whose tap
    /// changes the height of the layout stands in its row at once.
    private func sendStill(_ action: EditorAction) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { send(action) }
    }
}
