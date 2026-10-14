import ReelsmithCore
import SwiftUI

/// The choice of size and rate, in the sheet of the button `editor.exportSettings`. It decides nothing and holds no
/// state: a button shows the words of its case from Core, the chosen one has the trait selected and a filled
/// background, and a tap sends the settings `choosing` that case. Every button is always shown and a choice
/// changes no weight or size, so the sheet has one height and no button moves. The rows lay out from leading to
/// trailing, so Arabic mirrors them.
///
/// https://developer.apple.com/documentation/swiftui/button/init(action:label:)
/// https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
/// https://developer.apple.com/documentation/swiftui/view/background(_:alignment:)
/// https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
/// https://developer.apple.com/documentation/swiftui/view/linelimit(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct ExportSettingsSheet: View {
    let settings: ExportSettings
    let choose: @MainActor (ExportSettings) -> Void
    let done: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("export.settings")
                .font(.headline)
            Text("export.size")
            HStack(spacing: 8) {
                ForEach(ExportSize.allCases, id: \.shortSide) { size in
                    choice(size.words, "export.size." + String(describing: size), settings.size == size) {
                        settings.choosing(size)
                    }
                }
            }
            Text("export.rate")
            HStack(spacing: 8) {
                ForEach(ExportRate.allCases, id: \.framesPerSecond) { rate in
                    choice(rate.words, "export.rate." + String(describing: rate), settings.rate == rate) {
                        settings.choosing(rate)
                    }
                }
            }
            Button("export.settings.done") {
                done()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("export.settingsDone")
        }
        .padding()
    }

    /// One button as wide as its share of the row. The identifier names the case, as `export.size.hd720`.
    private func choice(
        _ words: Words, _ identifier: String, _ chosen: Bool, _ next: @escaping @MainActor () -> ExportSettings
    ) -> some View {
        Button {
            // With animations off the trait and the background change in the frame of the tap.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { choose(next()) }
        } label: {
            Text(text(words))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(chosen ? Color.accentColor.opacity(0.2) : Color.clear))
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
