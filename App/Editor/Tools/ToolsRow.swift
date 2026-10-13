import ReelsmithCore
import SwiftUI

/// The row of the two edit buttons and the text button. It decides nothing: Core says whether a button is enabled,
/// and a tap sends one action. A row of SwiftUI lays out from leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/button
/// https://developer.apple.com/documentation/swiftui/hstack
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct ToolsRow: View {
    let state: EditorState
    let send: @MainActor (EditorAction) -> Void

    var body: some View {
        HStack(spacing: 32) {
            Button("tools.split") { send(.split) }
                .disabled(!state.canSplit)
                .accessibilityIdentifier("editor.split")
            Button("tools.delete") { send(.deleteSelected) }
                .disabled(!state.canDelete)
                .accessibilityIdentifier("editor.delete")
            Button("tools.text") { send(.text(.add)) }
                .disabled(!state.canAddText)
                .accessibilityIdentifier("editor.addText")
        }
    }
}
