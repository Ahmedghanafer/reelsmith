import ReelsmithCore
import SwiftUI

/// More of the selected text: a row of the three sides of `TextAlign`, a slider for the line spacing and a
/// row of three toggles for the outline, the shadow and the box. It decides nothing and holds no state: a
/// control shows what the style of the selected text holds, and sends `setStyle` with that whole style
/// changed in one value. Core holds the line spacing between its limits. The alignment is a side of the
/// picture, so its row is laid out from left to right in every language. The slider and the toggles lay
/// out from leading to trailing, so Arabic mirrors them.
///
/// https://developer.apple.com/documentation/swiftui/slider/init(value:in:step:label:oneditingchanged:)
/// https://developer.apple.com/documentation/swiftui/toggle
/// https://developer.apple.com/documentation/swiftui/togglestyle/button
/// https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:)
/// https://developer.apple.com/documentation/swiftui/button/init(action:label:)
/// https://developer.apple.com/documentation/swiftui/binding/init(get:set:)
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/view/environment(_:_:)
/// https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
/// https://developer.apple.com/documentation/swiftui/text/fontweight(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct TextMore: View {
    let store: EditorStore

    var body: some View {
        let state: EditorState = store.state
        let selected: TextItem? = state.selectedText.flatMap { state.project.text($0) }
        if let selected {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(TextAlign.allCases, id: \.self) { align in
                        Button {
                            change(selected.id) { $0.align = align }
                        } label: {
                            Text(LocalizedStringKey("text.align." + align.rawValue))
                                .fontWeight(selected.style.align == align ? Font.Weight.bold : Font.Weight.regular)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("text.align." + align.rawValue)
                        .accessibilityAddTraits(selected.style.align == align ? .isSelected : [])
                    }
                }
                .environment(\.layoutDirection, LayoutDirection.leftToRight)
                HStack(spacing: 16) {
                    Text("text.spacing")
                    Slider(
                        value: Binding(
                            // Read at the call, so the slider never shows a spacing older than the one Core holds.
                            get: {
                                store.state.project.text(selected.id)?.style.lineSpacing ?? selected.style.lineSpacing
                            },
                            set: { spacing in change(selected.id) { $0.lineSpacing = spacing } }
                        ),
                        in: 0...2,
                        step: 0.1
                    ) {
                        Text("text.spacing")
                    }
                    .accessibilityIdentifier("text.spacing")
                }
                HStack(spacing: 0) {
                    mark("text.outline", selected.style.outline, of: selected) { $0.outline = $1 }
                    mark("text.shadow", selected.style.shadow, of: selected) { $0.shadow = $1 }
                    mark("text.box", selected.style.box, of: selected) { $0.box = $1 }
                }
            }
        }
    }

    /// One toggle drawn as a button, which a tap anywhere on it turns. Its word key is its identifier.
    private func mark(
        _ key: String, _ isOn: Bool, of selected: TextItem, _ set: @escaping (inout TextStyle, Bool) -> Void
    ) -> some View {
        Toggle(
            LocalizedStringKey(key),
            isOn: Binding(
                get: { isOn },
                set: { turned in change(selected.id) { set(&$0, turned) } }
            )
        )
        .toggleStyle(.button)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier(key)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Sends the style the text has at the call, changed in one value.
    private func change(_ id: TextID, _ edit: (inout TextStyle) -> Void) {
        guard var style: TextStyle = store.state.project.text(id)?.style else {
            return
        }
        edit(&style)
        store.send(.text(.setStyle(id, style)))
    }
}
