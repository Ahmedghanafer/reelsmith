import ReelsmithCore
import SwiftUI

/// The clip panel of the selected clip: one row with Delete before and Delete after the playhead, then, only while
/// the clip's media has sound, the slider of the clip's volume, then the framing row. It holds no state: Core says
/// whether a button is enabled and whether the slider shows, a tap sends one action, and the slider sends
/// `setVolumeOfClip` at each value of a drag, the whole drag one step of undo. It lays out from leading to
/// trailing, so Arabic mirrors it.
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
                    identifier: "clip.volume", label: "clip.volume", value: clip.volume, range: 0...2, step: 0.05,
                    send: { store.sendDragStep(.sound(.setVolumeOfClip(clip.id, $0))) }, follows: true,
                    ended: { store.endDrag() }
                )
                // Made anew for each clip, so a drag begun on one clip is never sent to the next one selected.
                // https://developer.apple.com/documentation/swiftui/view/id(_:)
                .id(clip.id)
            }
            if let framed: Clip = state.project.clips.first(where: { $0.id == state.selection }) {
                // A container, so each control keeps its own identifier. The picked fit and the blurred
                // backdrop are bold and have the trait selected.
                // https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:)
                // https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
                // https://developer.apple.com/documentation/swiftui/view/fontweight(_:)
                // https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
                HStack(spacing: 12) {
                    Button("clip.fit") { sendStill(.frame(.setFit(framed.id, .fit))) }
                        .fontWeight(framed.framing.fit == .fit ? Font.Weight.bold : Font.Weight.regular)
                        .accessibilityIdentifier("clip.fit")
                        .accessibilityAddTraits(framed.framing.fit == .fit ? .isSelected : [])
                    Button("clip.fill") { sendStill(.frame(.setFit(framed.id, .fill))) }
                        .fontWeight(framed.framing.fit == .fill ? Font.Weight.bold : Font.Weight.regular)
                        .accessibilityIdentifier("clip.fill")
                        .accessibilityAddTraits(framed.framing.fit == .fill ? .isSelected : [])
                    Button("clip.blur") {
                        // Read at the tap, so a second tap before the next render still turns the backdrop back.
                        let now = store.state.project.clips.first(where: { $0.id == framed.id })?.framing.backdrop
                        sendStill(.frame(.setBackdrop(framed.id, now == .blurred ? .black : .blurred)))
                    }
                    .fontWeight(framed.framing.backdrop == .blurred ? Font.Weight.bold : Font.Weight.regular)
                    .accessibilityIdentifier("clip.blur")
                    .accessibilityAddTraits(framed.framing.backdrop == .blurred ? .isSelected : [])
                    Button("clip.applyAll") { sendStill(.frame(.applyToAll(framed.id))) }
                        .accessibilityIdentifier("clip.applyAll")
                    // slot: guide
                    // Turns the Instagram guide over the picture on and off. Only the 9:16 canvas has one.
                    // https://developer.apple.com/documentation/swiftui/image/init(systemname:)
                    // https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-5f0zj
                    Button {
                        store.showsGuide.toggle()
                    } label: {
                        Image(systemName: "rectangle.dashed")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(InstagramGuide.safeArea(on: state.project.canvas) == nil)
                    .accessibilityLabel(Text("clip.guide"))
                    .accessibilityIdentifier("clip.guide")
                    .accessibilityAddTraits(store.showsGuide ? .isSelected : [])
                    // end slot: guide
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("clip.framing")
            }
            if store.options.showsInfo {
                Text(verbatim: state.frameInfo)
                    .font(.footnote)
                    .accessibilityIdentifier("clip.frameInfo")
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
