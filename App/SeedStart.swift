import Foundation
import ReelsmithCore
import ReelsmithEngine
import UIKit

/// The start on a seed: writes the seed's test clips and test tones once into `<caches>/Seeds/`, keeps a file
/// that is already there, and gives the store the editor opens with, the sound panel open when the seed says so.
/// Nil when the launch names no seed. A clip or a tone that cannot be written leaves its file missing: the file
/// count of `editor.seedInfo` shows it and the error is logged.
/// With -drafts the seed's project becomes a new draft on the shelf: each file it names is copied from
/// `<caches>/Seeds/` into the draft's media folder, and the store writes to the draft. Then one cover of the
/// seed's plan is tried, printed only.
///
/// https://developer.apple.com/documentation/foundation/filemanager/urls(for:in:)
/// https://developer.apple.com/documentation/foundation/filemanager/copyitem(at:to:)
@MainActor
func seedStart(_ options: LaunchOptions, shelf: DraftShelf) async -> EditorStore? {
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
    for tone in seed.testTones {
        do {
            _ = try await writeTestTone(tone, to: folder)
        } catch {
            NSLog("%@", "seed start: " + tone.name + ".mov was not written: \(error)")
        }
    }
    let project: Project = seed.project
    var state = EditorState(project: project)
    state.selectedText = seed.selectedText
    state.showsSound = seed.showsSound
    if let playhead: Time = options.playhead {
        state = reduce(state, .movePlayhead(playhead))
    }
    guard options.drafts != nil else {
        return EditorStore(state: state, mediaFolder: folder, options: options)
    }
    let draft: OpenDraft
    do {
        draft = try shelf.create(Draft(project: project, exportSettings: .startChoice, changed: Date()))
    } catch {
        NSLog("%@", "seed start: no draft was made, the editor opens on the seed folder: \(error)")
        return EditorStore(state: state, mediaFolder: folder, options: options)
    }
    for name in project.fileNames {
        do {
            try FileManager.default.copyItem(
                at: folder.appendingPathComponent(name), to: draft.mediaFolder.appendingPathComponent(name))
        } catch {
            NSLog("%@", "seed start: " + name + " was not copied into the draft: \(error)")
        }
    }
    let media: URL = draft.mediaFolder
    Task { await tryTheCover(of: project, in: media) }
    return EditorStore(state: state, mediaFolder: media, options: options, draft: draft)
}

/// The try of the cover in the simulator, printed only: one cover of the project's plan written by `writeCover`
/// to a file of its own under the temporary folder, never the draft's cover. One line beginning "cover try:"
/// names the width and height read back, or the error, or that no answer came within 30 seconds, and the
/// seconds. The file is removed after.
///
/// https://developer.apple.com/documentation/foundation/filemanager/temporarydirectory
/// https://developer.apple.com/documentation/swift/withtaskgroup(of:returning:isolation:body:)
/// https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)
/// https://developer.apple.com/documentation/uikit/uiimage/init(contentsoffile:)
/// https://developer.apple.com/documentation/coregraphics/cgimage/width
@MainActor
private func tryTheCover(of project: Project, in mediaFolder: URL) async {
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("cover-try-" + UUID().uuidString + ".jpg")
    let started = Date()
    let plan: RenderPlan
    do {
        plan = try renderPlan(for: project)
    } catch {
        NSLog("%@", "cover try: no plan, the error \(error), after \(Date().timeIntervalSince(started)) seconds")
        return
    }
    let media: [MediaID: MediaInfo] = project.media
    await withTaskGroup(of: String.self) { group in
        group.addTask {
            do {
                try await writeCover(plan: plan, media: media, mediaFolder: mediaFolder, to: file)
            } catch {
                return "the error \(error)"
            }
            guard let image = UIImage(contentsOfFile: file.path)?.cgImage else {
                return "a file that does not read back as a picture"
            }
            return "width \(image.width) height \(image.height)"
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            return "no answer within 30 seconds"
        }
        let first: String = await group.next() ?? "no answer"
        NSLog("%@", "cover try: " + first + ", after \(Date().timeIntervalSince(started)) seconds")
        group.cancelAll()
    }
    try? FileManager.default.removeItem(at: file)
}
