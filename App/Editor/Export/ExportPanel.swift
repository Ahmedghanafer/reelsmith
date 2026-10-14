import ReelsmithCore
import SwiftUI

/// The panel over the editor: the words of the export state, the percent while exporting, and one button
/// when the export has ended. While exporting it has no button, so there is no cancel.
/// The percent never mirrors: it is fixed left to right. On the saved panel the line `export.fileInfo` shows what
/// the written file holds, only when the button passes it.
///
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct ExportPanel: View {
    let state: ExportState
    let fileInfo: String?
    let close: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if let words = state.words {
                Text(text(words))
                    .font(.title2)
                    .accessibilityIdentifier("export.words")
            }
            if let percent = state.percentText {
                Text(percent)
                    .font(.largeTitle)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityIdentifier("export.percent")
            }
            if state == .saved, let fileInfo {
                Text(verbatim: fileInfo)
                    .font(.footnote)
                    .accessibilityIdentifier("export.fileInfo")
            }
            if state == .saved {
                Button("export.done") {
                    close()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("export.done")
            }
            if case .failed = state {
                Button("export.close") {
                    close()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("export.close")
            }
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}
