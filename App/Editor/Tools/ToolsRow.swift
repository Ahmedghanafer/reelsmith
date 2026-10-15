import ReelsmithCore
import SwiftUI

/// The row of the two edit buttons, the text button, the sound button, the button that adds clips and, at its trailing
/// end, the button that folds the frames of the blocks. It decides nothing: Core says whether a button is enabled, and a
/// tap sends one action, but for the fold, which toggles `framesFolded` of the store. A row of SwiftUI lays out from
/// leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/button
/// https://developer.apple.com/documentation/swiftui/image/init(systemname:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv
/// https://developer.apple.com/documentation/swiftui/hstack
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
struct ToolsRow: View {
    let store: EditorStore

    var body: some View {
        let state: EditorState = store.state
        HStack(spacing: 20) {
            Button("tools.split") { sendStill(.split) }
                .disabled(!state.canSplit)
                .accessibilityIdentifier("editor.split")
            Button("tools.delete") { sendStill(.deleteSelected) }
                .disabled(!state.canDelete)
                .accessibilityIdentifier("editor.delete")
            Button("tools.text") { sendStill(.text(.add)) }
                .disabled(!state.canAddText)
                .accessibilityIdentifier("editor.addText")
            Button("tools.sound") { sendStill(.sound(.open)) }
                .disabled(!state.canOpenSound)
                .accessibilityIdentifier("editor.sound")
            AddClips(store: store)
            // Folds the blocks of the strip to thin ones and back. No action of Core: the fold is the store's.
            Button {
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) { store.framesFolded.toggle() }
            } label: {
                Image(systemName: "rectangle.split.3x1")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("tools.frames"))
            .accessibilityIdentifier("editor.frames")
        }
    }

    /// Sends the action of a tap inside a transaction that disables animations, so a button whose tap
    /// changes the height of the layout stands in its row at once.
    private func sendStill(_ action: EditorAction) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { store.send(action) }
    }
}
