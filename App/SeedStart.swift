import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The start on a seed: writes the seed's test clips once into `<caches>/Seeds/`, keeps a file that is
/// already there, and gives the store the editor opens with. Nil when the launch names no seed.
/// A clip that cannot be written leaves its file missing: the file count of `editor.seedInfo` shows it
/// and the error is logged.
///
/// https://developer.apple.com/documentation/foundation/filemanager/urls(for:in:)
@MainActor
func seedStart(_ options: LaunchOptions) async -> EditorStore? {
    guard let seed: Seed = options.seed else { return nil }
    let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Seeds")
    for clip in seed.testClips {
        do {
            _ = try await writeTestClip(clip, to: folder)
        } catch {
            NSLog("%@", "seed start: " + clip.name + ".mov was not written: \(error)")
        }
    }
    let project: Project = seed.project
    var state = EditorState(project: project)
    state.selectedText = seed.selectedText
    if let playhead: Time = options.playhead {
        state = reduce(state, .movePlayhead(playhead))
    }
    return EditorStore(state: state, mediaFolder: folder, options: options)
}
