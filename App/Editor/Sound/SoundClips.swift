import ReelsmithCore
import SwiftUI

/// The part `clips` of the sound panel: the slider `sound.clipVolume` for the sound of every clip and, under it,
/// the toggle `sound.clipsMuted`. It decides nothing and holds no state: both read the project, the slider sends
/// `setClipVolume` and the toggle `muteClips`, and Core holds the volume between 0 and 1. A toggle that is on has
/// the trait selected. The part lays out from leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/toggle
/// https://developer.apple.com/documentation/swiftui/togglestyle/button
/// https://developer.apple.com/documentation/swiftui/binding/init(get:set:)
/// https://developer.apple.com/documentation/swiftui/spacer
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
/// https://developer.apple.com/documentation/swiftui/view/transaction(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct SoundClips: View {
    let store: EditorStore

    var body: some View {
        let project: Project = store.state.project
        VStack(spacing: 8) {
            SoundSlider(
                identifier: "sound.clipVolume", label: "sound.clipVolume", value: project.clipVolume, range: 0...1,
                step: 0.05, send: { store.send(.sound(.setClipVolume($0))) })
            HStack {
                // Read at the call, so two quick taps turn it twice. The change is made with animations off, so
                // the toggle shows it in the same frame as the line of the sound.
                Toggle(
                    isOn: Binding(
                        get: { store.state.project.clipsMuted },
                        set: { muted in
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) { store.send(.sound(.muteClips(muted))) }
                        }
                    )
                ) {
                    Text("sound.clipsMuted")
                }
                .toggleStyle(.button)
                .transaction { transaction in transaction.animation = nil }
                .accessibilityIdentifier("sound.clipsMuted")
                .accessibilityAddTraits(project.clipsMuted ? .isSelected : [])
                Spacer()
            }
            .frame(minHeight: 44)
        }
    }
}
