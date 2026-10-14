import ReelsmithCore
import SwiftUI

/// The look of the selected text: a row of the faces of `TextFont`, a row of the colours of
/// `TextStyle.palette` and a slider for the size. It decides nothing and holds no state: a control shows
/// what the style of the selected text holds, and sends `setStyle` with that whole style changed in one
/// value. Core holds the size between its limits, and the slider takes its two ends from Core. The rows lay
/// out from leading to trailing, so Arabic mirrors them.
///
/// https://developer.apple.com/documentation/swiftui/slider/init(value:in:step:label:oneditingchanged:)
/// https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:)
/// https://developer.apple.com/documentation/swiftui/button/init(action:label:)
/// https://developer.apple.com/documentation/swiftui/binding/init(get:set:)
/// https://developer.apple.com/documentation/swiftui/color/init(_:red:green:blue:opacity:)
/// https://developer.apple.com/documentation/swiftui/circle
/// https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
/// https://developer.apple.com/documentation/swiftui/view/fontweight(_:)
/// https://developer.apple.com/documentation/swiftui/view/opacity(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-5f0zj
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct TextLook: View {
    let store: EditorStore

    var body: some View {
        let state: EditorState = store.state
        let selected: TextItem? = state.selectedText.flatMap { state.project.text($0) }
        if let selected {
            VStack(spacing: 8) {
                HStack(spacing: 24) {
                    ForEach(TextFont.allCases, id: \.self) { font in
                        Button(text(font.words)) { change(selected.id) { $0.font = font } }
                            .fontWeight(selected.style.font == font ? Font.Weight.bold : Font.Weight.regular)
                            .accessibilityIdentifier("text.font." + font.rawValue)
                            .accessibilityAddTraits(selected.style.font == font ? .isSelected : [])
                    }
                    Spacer()
                }
                .frame(minHeight: 44)
                HStack(spacing: 0) {
                    ForEach(Array(TextStyle.palette.indices), id: \.self) { index in
                        swatch(index, of: selected)
                    }
                }
                HStack(spacing: 16) {
                    Text("text.size")
                    Slider(
                        value: Binding(
                            // Read at the call, so the slider never shows a size older than the one Core holds.
                            get: { store.state.project.text(selected.id)?.style.size ?? selected.style.size },
                            set: { size in change(selected.id) { $0.size = size } }
                        ),
                        in: TextGeometry.minimumSize...TextGeometry.maximumSize,
                        step: 2
                    ) {
                        Text("text.size")
                    }
                    .accessibilityIdentifier("text.size")
                }
            }
        }
    }

    /// One colour button: a disc of the colour, with a ring around it when the text has that colour. Its
    /// label names it by its number in the palette, counted from 1.
    private func swatch(_ index: Int, of selected: TextItem) -> some View {
        let colour: RGB = TextStyle.palette[index]
        let isChosen: Bool = selected.style.colour == colour
        return Button {
            change(selected.id) { $0.colour = colour }
        } label: {
            Circle()
                .fill(
                    Color(
                        .sRGB, red: Double(colour.r) / 255, green: Double(colour.g) / 255,
                        blue: Double(colour.b) / 255, opacity: 1)
                )
                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                .frame(width: 26, height: 26)
                .padding(5)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 3).opacity(isChosen ? 1 : 0))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(text(Words("text.colour", [String(index + 1)]))))
        .accessibilityIdentifier("text.colour." + String(index + 1))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
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
