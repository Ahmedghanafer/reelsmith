import ReelsmithCore
import SwiftUI

/// The panel over the editor: the words of the export state, the percent while exporting, and one button
/// when the export has ended. While exporting it has no button, so there is no cancel.
/// The percent never mirrors: it is fixed left to right.
///
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct ExportPanel: View {
    let state: ExportState
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
