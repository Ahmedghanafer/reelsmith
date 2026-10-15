import ReelsmithCore
import SwiftUI

/// The preview of the editor: the picture area in the shape of the project's canvas, and under it the
/// row of the button to the projects, the play button, the time label and, at its trailing end, undo, redo and
/// save, 8 points apart so all six fit the width of the phone. It decides nothing:
/// the label is `timeLabel`, the symbol follows `isPlaying`, the button is enabled by `canPlay`, and a tap
/// sends `play` or `pause`. Undo and redo are always shown and enabled by `canUndo` and `canRedo`, so
/// nothing in the row moves when one is enabled. Save is always shown and enabled, and writes the draft.
/// The button to the projects is always enabled and closes the store, which takes her back to the start screen.
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
                .overlay {
                    if store.showsGuide, let safe = InstagramGuide.safeArea(on: state.project.canvas) {
                        InstagramGuideView(safe: safe, canvasWidth: Double(state.project.canvas.width))
                    }
                }
                // On the picture itself, not on the space around it: the recognizers of `TextGestures`.
                .modifier(TextGestures(store: store))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 8) {
                // slot: projects
                Button {
                    still { Task { await store.close() } }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("editor.projects"))
                .accessibilityIdentifier("editor.projects")
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
                Button {
                    still { store.write() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("draft.save"))
                .accessibilityIdentifier("editor.save")
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    /// Runs a tap inside a transaction that disables animations: an undo can close a panel and change the
    /// height of the layout, and the row must stand at once. Save and the button to the projects are sent the same way.
    private func still(_ tap: () -> Void) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still, tap)
    }
}

/// The Instagram guide over the picture: a tint outside the safe area, and the safe area itself, outlined, the
/// accessibility element `editor.guide.safe`. The screen draws it over the picture, so it is never in a plan, a cover
/// or an export, and it takes no touch: the gestures on the picture go through it.
///
/// https://developer.apple.com/documentation/swiftui/view/overlay(alignment:content:)
/// https://developer.apple.com/documentation/swiftui/geometryreader
/// https://developer.apple.com/documentation/swiftui/path
/// https://developer.apple.com/documentation/swiftui/shape/fill(_:style:)
/// https://developer.apple.com/documentation/swiftui/fillstyle/init(eofill:antialiased:)
/// https://developer.apple.com/documentation/swiftui/insettableshape/strokeborder(_:linewidth:antialiased:)
/// https://developer.apple.com/documentation/swiftui/view/position(x:y:)
/// https://developer.apple.com/documentation/swiftui/view/allowshittesting(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:)
private struct InstagramGuideView: View {
    /// `InstagramGuide.safeArea` in canvas pixels.
    let safe: (x: Double, y: Double, width: Double, height: Double)
    let canvasWidth: Double

    var body: some View {
        GeometryReader { proxy in
            // The picture has the shape of the canvas, so its width gives the scale of both axes.
            let scale: Double = Double(proxy.size.width) / canvasWidth
            let hole = CGRect(
                x: safe.x * scale, y: safe.y * scale, width: safe.width * scale, height: safe.height * scale)
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRect(hole)
                }
                .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                // Inside its frame: a line on the edge would reach half its width past the safe area, and the
                // element's frame with it.
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    .frame(width: hole.width, height: hole.height)
                    .accessibilityElement()
                    .accessibilityLabel(Text("clip.guide"))
                    .accessibilityIdentifier("editor.guide.safe")
                    .position(x: hole.midX, y: hole.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.guide")
    }
}
