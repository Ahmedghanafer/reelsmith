import ReelsmithCore
import SwiftUI

/// The panel of the selected text: one row with the three part buttons and, at its trailing end, the done
/// button, and under the row the part that shows. Which part shows is the one state of the panel: `type`
/// when the text is blank at the moment the panel is made for it, `look` otherwise. Everything else is the
/// state of the store. The done button only clears the selection, and Core removes a text that is left blank.
/// The row lays out from leading to trailing, so Arabic mirrors it, and the field takes its direction from
/// what is typed.
///
/// https://developer.apple.com/documentation/swiftui/texteditor
/// https://developer.apple.com/documentation/swiftui/binding/init(get:set:)
/// https://developer.apple.com/documentation/swiftui/state/init(initialvalue:)
/// https://developer.apple.com/documentation/swiftui/view/fontweight(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-5f0zj
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
struct TextPanel: View {
    let store: EditorStore

    private enum Part {
        case type
        case look
        case more
    }

    @State private var part: Part

    init(store: EditorStore) {
        self.store = store
        let state: EditorState = store.state
        let selected: TextItem? = state.selectedText.flatMap { state.project.text($0) }
        _part = State(initialValue: selected?.isBlank == true ? Part.type : Part.look)
    }

    var body: some View {
        let state: EditorState = store.state
        let selected: TextItem? = state.selectedText.flatMap { state.project.text($0) }
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                tab(.type, "text.tab.type")
                tab(.look, "text.tab.look")
                tab(.more, "text.tab.more")
                Spacer()
                Button("text.done") { still { store.send(.clearSelection) } }
                    .accessibilityIdentifier("text.done")
            }
            .frame(minHeight: 44)
            if part == .type, let selected {
                TextEditor(
                    text: Binding(
                        // Read at the call, so the field never gets a string older than the one it sent.
                        get: { store.state.project.text(selected.id)?.string ?? "" },
                        set: { store.send(.text(.setString(selected.id, $0))) }
                    )
                )
                .frame(height: 88)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
                .accessibilityLabel(Text("text.field"))
                .accessibilityIdentifier("text.field")
            }
            if part == .look {
                // slot: look
                TextLook(store: store)
                // end slot: look
            }
            if part == .more {
                // slot: more
                TextMore(store: store)
                // end slot: more
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
