import Foundation
import ReelsmithCore
import ReelsmithEngine

extension Engine {
    /// The launch values parsed by `LaunchOptions` and the two folders of the drafts, as one JSON object with
    /// sorted keys: `seed` and `drafts` by their raw values, `playhead` in ticks, each null when not given,
    /// `exportFails`, `draftsFolder` (`<Application Support>/Drafts`) and `testDraftsFolder`
    /// (`<caches>/TestDrafts`). A new launch value is a new key and needs no change of the Pigeon file.
    ///
    /// https://developer.apple.com/documentation/foundation/filemanager/urls(for:in:)
    /// https://developer.apple.com/documentation/foundation/jsonserialization/data(withjsonobject:options:)
    func launch() throws -> String {
        // The debug guard of the launch values: only a debug build reads the process arguments.
        #if DEBUG
        let options = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        #else
        let options = LaunchOptions(arguments: [])
        #endif
        let manager = FileManager.default
        let applicationSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var values: [String: Any] = [
            "seed": NSNull(),
            "playhead": NSNull(),
            "exportFails": options.exportFails,
            "drafts": NSNull(),
            "draftsFolder": applicationSupport.appendingPathComponent("Drafts").path,
            "testDraftsFolder": caches.appendingPathComponent("TestDrafts").path,
        ]
        if let seed = options.seed {
            values["seed"] = seed.rawValue
        }
        if let playhead = options.playhead {
            values["playhead"] = playhead.ticks
        }
        if let drafts = options.drafts {
            values["drafts"] = drafts.rawValue
        }
        if let name = options.draftFixture {
            copyDraftFixture(name, caches: caches)
        }
        let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// `-draft-fixture <name>`: the fixture `DraftFixtures/swift/<name>.json` of a debug bundle becomes the draft
    /// `<caches>/TestDrafts/<name>/draft.json`, in place of a draft of that name, and every file of `<caches>/Seeds/`
    /// is copied into its `Media`, so the clips and the music a seed start wrote there are found. The shelf removes
    /// the files the draft does not name when it opens it. A fixture that is not in the bundle, or a copy that
    /// fails, is logged.
    ///
    /// https://developer.apple.com/documentation/foundation/bundle/resourceurl
    /// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
    /// https://developer.apple.com/documentation/foundation/filemanager/copyitem(at:to:)
    /// https://developer.apple.com/documentation/foundation/filemanager/contentsofdirectory(at:includingpropertiesforkeys:options:)
    private func copyDraftFixture(_ name: String, caches: URL) {
        let manager = FileManager.default
        guard let resources = Bundle.main.resourceURL else {
            NSLog("%@", "draft fixture: the bundle has no resources, " + name + " was not copied")
            return
        }
        let fixture = resources.appendingPathComponent("DraftFixtures").appendingPathComponent("swift")
            .appendingPathComponent(name + ".json")
        guard !name.isEmpty, manager.fileExists(atPath: fixture.path) else {
            NSLog("%@", "draft fixture: no fixture " + name + ".json in the bundle")
            return
        }
        let draft = caches.appendingPathComponent("TestDrafts").appendingPathComponent(name)
        let media = draft.appendingPathComponent("Media")
        let seeds = caches.appendingPathComponent("Seeds")
        do {
            if manager.fileExists(atPath: draft.path) {
                try manager.removeItem(at: draft)
            }
            try manager.createDirectory(at: media, withIntermediateDirectories: true)
            try manager.copyItem(at: fixture, to: draft.appendingPathComponent("draft.json"))
            let files = (try? manager.contentsOfDirectory(at: seeds, includingPropertiesForKeys: nil)) ?? []
            for file in files {
                try manager.copyItem(at: file, to: media.appendingPathComponent(file.lastPathComponent))
            }
        } catch {
            NSLog("%@", "draft fixture: " + name + " was not copied: \(error)")
        }
    }

    /// Writes the seed's test clips, test tones and test photos once into `<caches>/Seeds/`, keeps a file that is
    /// already there, and gives that folder. A clip, a tone or a photo that cannot be written leaves its file
    /// missing and the error is logged. A test photo is written as its picture, then as its still movie through
    /// `importPhoto`, which is the file the seed's project names. An unknown name writes nothing.
    ///
    /// https://developer.apple.com/documentation/foundation/filemanager/urls(for:in:)
    /// https://developer.apple.com/documentation/foundation/filemanager/fileexists(atpath:)
    func writeSeedMedia(seed name: String) async throws -> String {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Seeds")
        guard let seed = Seed(rawValue: name) else { return folder.path }
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
        return folder.path
    }
}
