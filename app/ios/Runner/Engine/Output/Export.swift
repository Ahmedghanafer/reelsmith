import Foundation
import ReelsmithCore
import ReelsmithEngine
import UIKit

/// The export and the awake screen, moved from `App/Editor/Export/ExportToPhotos.swift` and `ExportButton.swift`.
///
/// https://developer.apple.com/documentation/foundation/filemanager/temporarydirectory
/// https://developer.apple.com/documentation/foundation/jsondecoder
/// https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled
/// https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)
extension Engine {
    /// Exports the project at the settings to a file in the app's temporary folder, sending its progress as
    /// `ExportProgressEvent`, and gives the file with the facts read from it, nil when the read threw. Every
    /// error of the plan and of the Engine is thrown, and the file is removed. With `fails` the output place lies
    /// in a folder that is not there, so the Engine throws `cannotWrite` before any work. The project is the JSON
    /// of a project as the `project` member of the draft JSON holds it, the settings the JSON of `ExportSettings`.
    func export(project: String, settings: String, mediaFolder: String, fails: Bool) async throws -> ExportedVideo {
        let exported = try JSONDecoder().decode(Project.self, from: Data(project.utf8))
        let chosen = try JSONDecoder().decode(ExportSettings.self, from: Data(settings.utf8))
        let temporary = FileManager.default.temporaryDirectory
        let output = fails
            ? temporary.appendingPathComponent(UUID().uuidString).appendingPathComponent("export.mp4")
            : temporary.appendingPathComponent(UUID().uuidString + ".mp4")
        let events = self.events
        do {
            let plan = try renderPlan(for: exported, settings: chosen)
            try await ReelsmithEngine.export(
                plan: plan, media: exported.media, mediaFolder: URL(fileURLWithPath: mediaFolder), to: output
            ) { value in
                events.send(ExportProgressEvent(progress: value))
            }
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        let facts = try? await readVideoFacts(of: output)
        return ExportedVideo(file: output.path, facts: facts?.infoText)
    }

    /// While true the phone does not lock. Dart sets it true while an export runs and false once it ends, saved
    /// or failed, as `ExportState.keepsScreenAwake` says. Flutter calls it on the main thread.
    func keepAwake(awake: Bool) throws {
        MainActor.assumeIsolated {
            UIApplication.shared.isIdleTimerDisabled = awake
        }
    }
}
