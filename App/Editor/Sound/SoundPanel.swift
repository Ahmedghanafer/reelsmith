import ReelsmithCore
import SwiftUI

/// The sound panel: one row with the three part buttons and, at its trailing end, the done button, and under
/// the row the part that shows. Which part shows is the one state of the panel, `music` when the panel is made.
/// Each part is a slot of this file, and a slot that is empty shows nothing under the row. The done button only
/// clears the selection, which closes the panel. The row lays out from leading to trailing, so Arabic mirrors it.
///
/// https://developer.apple.com/documentation/swiftui/state
/// https://developer.apple.com/documentation/swiftui/view/frame(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:alignment:)
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

    /// The least height under the row: what levels needs, a label and four sound sliders of about 31 points, 8 apart,
    /// which the simulator measured a third of a point above 176, with room.
    private let partHeight: CGFloat = 184

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
            VStack(spacing: 0) {
            if part == .music {
                // slot: music
                MusicPart(store: store)
                // end slot: music
            }
            if part == .levels {
                // slot: levels
                MusicLevels(store: store)
                // end slot: levels
            }
            if part == .clips {
                // slot: clips
                SoundClips(store: store)
                // end slot: clips
            }
            }
            .frame(maxWidth: .infinity, minHeight: partHeight, alignment: .top)
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
