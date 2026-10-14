import ReelsmithCore
import SwiftUI
import UIKit

/// The export button and the panel it puts over the editor. It decides nothing: `ExportState` says whether the
/// button is enabled and what the panel shows, and only `ExportState.after(_:)` moves it.
/// The panel is a full screen cover, so nothing of the editor behind it answers a touch.
///
/// https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/binding/constant(_:)
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct ExportButton: View {
    let store: EditorStore

    @State private var exportState = ExportState.idle

    var body: some View {
        Button("export.button") {
            start()
        }
        .disabled(!exportState.canStart(store.state))
        .accessibilityIdentifier("editor.export")
        .fullScreenCover(isPresented: .constant(exportState != .idle)) {
            ExportPanel(state: exportState, close: { exportState = exportState.after(.closed) })
        }
        // The phone does not lock while an export runs, and may lock again once it ends, saved or failed.
        // https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled
        // https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)
        .onChange(of: exportState) {
            UIApplication.shared.isIdleTimerDisabled = exportState.keepsScreenAwake
        }
    }

    /// Exports the project as it is at the tap. There is no cancel: the task runs to its end.
    private func start() {
        guard exportState.canStart(store.state) else { return }
        store.send(.pause)
        exportState = exportState.after(.started)
        let project = store.state.project
        let mediaFolder = store.mediaFolder
        let fails = store.options.exportFails
        Task {
            let outcome = await exportToPhotos(project: project, mediaFolder: mediaFolder, fails: fails) { value in
                // The Engine reports progress off the main actor.
                Task { @MainActor in
                    exportState = exportState.after(.progress(value))
                }
            }
            exportState = exportState.after(outcome)
        }
    }
}
