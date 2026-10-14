import ReelsmithCore
import ReelsmithEngine
import SwiftUI
import UIKit

/// The export row: the choice of size and rate, then the export button and the panel it puts over the editor.
/// It decides nothing: `ExportState` says whether the button is enabled and what the panel shows, and only
/// `ExportState.after(_:)` moves it. The choice is its own state from the start choice of Core until the editor
/// goes, and the sheet of the choice sends the settings it is given back. The two buttons take an equal share of
/// the row, so the export button stands still whatever the label of the choice says.
/// The panel is a full screen cover, so nothing of the editor behind it answers a touch.
///
/// https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)
/// https://developer.apple.com/documentation/swiftui/binding/constant(_:)
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct ExportButton: View {
    let store: EditorStore

    @State private var exportState = ExportState.idle
    @State private var settings = ExportSettings.startChoice
    @State private var savedFacts: VideoFacts?
    @State private var choosing = false

    var body: some View {
        HStack(spacing: 8) {
            choice
            exportButton
        }
    }

    /// The words of the chosen size and rate, side by side. A tap shows the sheet of the choice.
    private var choice: some View {
        Button {
            choosing = true
        } label: {
            Text(text(settings.size.words) + " " + text(settings.rate.words))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("editor.exportSettings")
        .sheet(isPresented: $choosing) {
            ExportSettingsSheet(settings: settings, choose: { settings = $0 }, done: { choosing = false })
                .presentationDetents([.medium])
        }
    }

    private var exportButton: some View {
        Button {
            start()
        } label: {
            Text("export.button")
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(!exportState.canStart(store.state))
        .accessibilityIdentifier("editor.export")
        .fullScreenCover(isPresented: .constant(exportState != .idle)) {
            ExportPanel(
                state: exportState,
                // Only a seeded start shows what the file holds, "none" when it could not be read.
                fileInfo: store.options.seed != nil ? (savedFacts?.infoText ?? "none") : nil,
                close: { exportState = exportState.after(.closed) })
        }
        // The phone does not lock while an export runs, and may lock again once it ends, saved or failed.
        // https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled
        // https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)
        .onChange(of: exportState) {
            UIApplication.shared.isIdleTimerDisabled = exportState.keepsScreenAwake
        }
    }

    /// Exports the project as it is at the tap, at the choice shown. There is no cancel: the task runs to its end.
    private func start() {
        guard exportState.canStart(store.state) else { return }
        store.send(.pause)
        exportState = exportState.after(.started)
        let project = store.state.project
        let chosen = settings
        let mediaFolder = store.mediaFolder
        let fails = store.options.exportFails
        Task {
            let outcome = await exportToPhotos(
                project: project, settings: chosen, mediaFolder: mediaFolder, fails: fails
            ) { value in
                // The Engine reports progress off the main actor.
                Task { @MainActor in
                    exportState = exportState.after(.progress(value))
                }
            }
            savedFacts = outcome.facts
            exportState = exportState.after(outcome.event)
        }
    }
}
