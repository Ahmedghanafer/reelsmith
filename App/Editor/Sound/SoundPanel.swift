import ReelsmithCore
import SwiftUI

/// The sound panel: one row with the three part buttons and, at its trailing end, the done button, and under
/// the row the part that shows. Which part shows is the one state of the panel, `music` when the panel is made.
/// Each part is a slot of this file, and a slot that is empty shows nothing under the row. The done button only
/// clears the selection, which closes the panel. The row lays out from leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/state
/// https://developer.apple.com/documentation/swiftui/view/fontweight(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
struct SoundPanel: View {
    let store: EditorStore

    private enum Part {
        case music
        case levels
        case clips
    }

    @State private var part: Part = .music

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                tab(.music, "sound.tab.music")
                tab(.levels, "sound.tab.levels")
                tab(.clips, "sound.tab.clips")
                Spacer()
                Button("sound.done") { still { store.send(.clearSelection) } }
                    .accessibilityIdentifier("sound.done")
            }
            .frame(minHeight: 44)
            if part == .music {
                // slot: music
                MusicPart(store: store)
                // end slot: music
            }
            if part == .levels {
                // slot: levels
                // end slot: levels
            }
            if part == .clips {
                // slot: clips
                SoundClips(store: store)
                // end slot: clips
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// One part button. Its word key is its identifier, and the part that shows has the trait selected.
    private func tab(_ shown: Part, _ key: String) -> some View {
        Button(LocalizedStringKey(key)) { still { part = shown } }
            .fontWeight(part == shown ? Font.Weight.bold : Font.Weight.regular)
            .accessibilityIdentifier(key)
            .accessibilityAddTraits(part == shown ? .isSelected : [])
    }

    /// Makes the change of a tap inside a transaction that disables animations, so a button whose tap
    /// changes the height of the layout stands in its row at once.
    private func still(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { change() }
    }
}
