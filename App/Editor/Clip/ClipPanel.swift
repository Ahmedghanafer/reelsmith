import ReelsmithCore
import SwiftUI

/// The clip panel of the selected clip: one row with Delete before and Delete after the playhead, then, only while
/// the clip's media has sound, the slider of the clip's volume. It decides nothing and holds no state: Core says
/// whether a button is enabled and whether the slider shows, a tap sends one action, and the slider sends
/// `setVolumeOfClip` once, when its drag ends. It lays out from leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/button
/// https://developer.apple.com/documentation/swiftui/hstack
/// https://developer.apple.com/documentation/swiftui/vstack
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
struct ClipPanel: View {
    let store: EditorStore

    var body: some View {
        let state: EditorState = store.state
        let clip: Clip? = state.showsClipVolume ? state.project.clips.first(where: { $0.id == state.selection }) : nil
        VStack(spacing: 8) {
            HStack(spacing: 32) {
                Button("clip.cutBefore") { sendStill(.cutBefore) }
                    .disabled(!state.canCutBefore)
                    .accessibilityIdentifier("clip.cutBefore")
                Button("clip.cutAfter") { sendStill(.cutAfter) }
                    .disabled(!state.canCutAfter)
                    .accessibilityIdentifier("clip.cutAfter")
            }
            .frame(minHeight: 44)
            if let clip {
                SoundSlider(
                    identifier: "clip.volume", label: "clip.volume", value: clip.volume, range: 0...1, step: 0.05,
                    send: { store.send(.sound(.setVolumeOfClip(clip.id, $0))) }
                )
                // Made anew for each clip, so a drag begun on one clip is never sent to the next one selected.
                // https://developer.apple.com/documentation/swiftui/view/id(_:)
                .id(clip.id)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Sends the action of a tap inside a transaction that disables animations, so a cut that changes the strip
    /// shows in the same frame.
    private func sendStill(_ action: EditorAction) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { store.send(action) }
    }
}
