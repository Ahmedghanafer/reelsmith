import ReelsmithCore
import SwiftUI

/// The preview of the editor: the picture area in the shape of the project's canvas, and under it the
/// play button and the time label. It decides nothing: the label is `timeLabel`, the symbol follows
/// `isPlaying`, the button is enabled by `canPlay`, and a tap sends `play` or `pause`.
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 16) {
                Button {
                    store.send(state.isPlaying ? .pause : .play)
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
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
