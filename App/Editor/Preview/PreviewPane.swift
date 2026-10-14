import ReelsmithCore
import SwiftUI

/// The preview of the editor: the picture area in the shape of the project's canvas, and under it the
/// row of the play button, the time label and, at its trailing end, undo and redo. It decides nothing:
/// the label is `timeLabel`, the symbol follows `isPlaying`, the button is enabled by `canPlay`, and a tap
/// sends `play` or `pause`. Undo and redo are always shown and enabled by `canUndo` and `canRedo`, so
/// nothing in the row moves when one is enabled.
/// Never mirrored: the whole pane is fixed left to right.
///
/// https://developer.apple.com/documentation/swiftui/view/aspectratio(_:contentmode:)-771ow
/// https://developer.apple.com/documentation/swiftui/button
/// https://developer.apple.com/documentation/swiftui/image/init(systemname:)
/// https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
/// https://developer.apple.com/documentation/swiftui/view/monospaceddigit()
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-5f0zj
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/view/modifier(_:)
/// https://developer.apple.com/documentation/swiftui/spacer
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
struct PreviewPane: View {
    let store: EditorStore

    var body: some View {
        let state: EditorState = store.state
        let words: LocalizedStringKey = state.isPlaying ? "preview.pause" : "preview.play"
        VStack(spacing: 8) {
            // The shape is the canvas of the project, its width to its height. The picture is as large
            // as fits whole in the space above the button, and stands in its middle.
            PlayerPicture(state: state, store: store)
                .aspectRatio(
                    CGSize(width: state.project.canvas.width, height: state.project.canvas.height),
                    contentMode: .fit
                )
                // On the picture itself, not on the space around it: the recognizers of `TextGestures`.
                .modifier(TextGestures(store: store))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 16) {
                // slot: projects
                // end slot: projects
                Button {
                    // Read at the tap, so a pause the player sent a moment ago is seen.
                    store.send(store.state.isPlaying ? .pause : .play)
                } label: {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }
                .disabled(!state.canPlay)
                .accessibilityLabel(Text(words))
                .accessibilityIdentifier("editor.play")
                Text(verbatim: state.timeLabel)
                    .monospacedDigit()
                    .accessibilityIdentifier("editor.time")
                Spacer()
                Button {
                    still { store.undo() }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 44, height: 44)
                }
                .disabled(!store.editing.canUndo)
                .accessibilityLabel(Text("editor.undo"))
                .accessibilityIdentifier("editor.undo")
                Button {
                    still { store.redo() }
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .frame(width: 44, height: 44)
                }
                .disabled(!store.editing.canRedo)
                .accessibilityLabel(Text("editor.redo"))
                .accessibilityIdentifier("editor.redo")
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    /// Runs a tap inside a transaction that disables animations: an undo can close a panel and change the
    /// height of the layout, and the row must stand at once.
    private func still(_ tap: () -> Void) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still, tap)
    }
}
