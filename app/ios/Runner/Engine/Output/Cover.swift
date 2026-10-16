import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The cover of a draft, moved from `makeCover` of `App/Editor/EditorStore.swift`.
///
/// https://developer.apple.com/documentation/foundation/filemanager/fileexists(atpath:)
/// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
/// https://developer.apple.com/documentation/foundation/jsondecoder
extension Engine {
    /// Writes the cover of the project's plan to the file when the project has a clip, else removes that file.
    /// A throw of the plan or of the Engine is logged and leaves the file as it was. The project is the JSON of a
    /// project as the `project` member of the draft JSON holds it. One that cannot be read throws.
    func writeCover(project: String, mediaFolder: String, file: String) async throws {
        let covered = try JSONDecoder().decode(Project.self, from: Data(project.utf8))
        let coverFile = URL(fileURLWithPath: file)
        guard !covered.clips.isEmpty else {
            if FileManager.default.fileExists(atPath: coverFile.path) {
                do {
                    try FileManager.default.removeItem(at: coverFile)
                } catch {
                    NSLog("%@", "editor: the cover was not removed: \(error)")
                }
            }
            return
        }
        do {
            let plan = try renderPlan(for: covered)
            try await ReelsmithEngine.writeCover(
                plan: plan, media: covered.media, mediaFolder: URL(fileURLWithPath: mediaFolder), to: coverFile)
        } catch {
            NSLog("%@", "editor: the cover was not written: \(error)")
        }
    }
}
