import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The start on a seed: writes the seed's test clips, test tones and test photos once into `<caches>/Seeds/`, keeps
/// a file that is already there, and gives the store the editor opens with, the sound panel open when the seed says
/// so. Nil when the launch names no seed. A clip, a tone or a photo that cannot be written leaves its file missing:
/// the file count of `editor.seedInfo` shows it and the error is logged. A test photo is written as its picture,
/// then as its still movie through `importPhoto`, which is the file the seed's project names.
/// With -drafts the seed's project becomes a new draft on the shelf: each file it names is copied from
/// `<caches>/Seeds/` into the draft's media folder, and the store writes to the draft.
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
    for photo in seed.testPhotos where !FileManager.default.fileExists(
        atPath: folder.appendingPathComponent(photo.info.fileName).path) {
        do {
            let picture = try writeTestPhoto(photo, to: folder)
            _ = try await importPhoto(from: picture, id: photo.info.id, into: folder)
        } catch {
            NSLog("%@", "seed start: " + photo.info.fileName + " was not written: \(error)")
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
    return EditorStore(state: state, mediaFolder: draft.mediaFolder, options: options, draft: draft)
}
