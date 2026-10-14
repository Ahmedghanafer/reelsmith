import Foundation

/// The folder of drafts: one folder `<folder>/<id>/` a draft, holding draft.json, Media and, once written, cover.jpg.
/// Only the shelf and `OpenDraft` make, read, write or remove anything under `folder`.
/// https://developer.apple.com/documentation/foundation/filemanager
public struct DraftShelf: Equatable, Sendable {
    /// The drafts folder of rule 59.
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    func draftFolder(of id: DraftID) -> URL {
        folder.appendingPathComponent(id.raw, isDirectory: true)
    }

    func draftFile(of id: DraftID) -> URL {
        draftFolder(of: id).appendingPathComponent("draft.json", isDirectory: false)
    }

    /// `<folder>/<id>/Media`.
    public func mediaFolder(of id: DraftID) -> URL {
        draftFolder(of: id).appendingPathComponent("Media", isDirectory: true)
    }

    /// `<folder>/<id>/cover.jpg`.
    public func coverFile(of id: DraftID) -> URL {
        draftFolder(of: id).appendingPathComponent("cover.jpg", isDirectory: false)
    }

    /// A new id, `<folder>/<id>/Media` made with every folder above it, draft.json written.
    /// When the write fails the new folder is removed again, so no draft is left.
    public func create(_ draft: Draft) throws -> OpenDraft {
        let open = OpenDraft(shelf: self, id: DraftID(UUID().uuidString))
        do {
            try FileManager.default.createDirectory(at: open.mediaFolder, withIntermediateDirectories: true)
        } catch {
            NSLog("%@", "drafts: the folder of a new draft was not made: \(error)")
            throw DraftError.cannotWrite
        }
        do {
            try open.write(draft)
        } catch {
            try? FileManager.default.removeItem(at: draftFolder(of: open.id))
            throw DraftError.cannotWrite
        }
        return open
    }

    /// One summary for each folder in `folder`, from its draft.json, unreadable when that is missing or throws.
    /// Newest changed first, a tie by id, the unreadable last by id. A folder that is not there gives none, and
    /// one that cannot be read gives none and a log line.
    public func list() -> [DraftSummary] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: folder.path) else {
            return []
        }
        let names: [String]
        do {
            names = try manager.contentsOfDirectory(atPath: folder.path)
        } catch {
            NSLog("%@", "drafts: the folder of drafts was not read: \(error)")
            return []
        }
        var readable: [DraftSummary] = []
        var unreadable: [DraftSummary] = []
        for name in names {
            let id = DraftID(name)
            var isFolder: ObjCBool = false
            guard manager.fileExists(atPath: draftFolder(of: id).path, isDirectory: &isFolder), isFolder.boolValue
            else {
                continue
            }
            let hasCover = manager.fileExists(atPath: coverFile(of: id).path)
            if let data = try? Data(contentsOf: draftFile(of: id)), let draft = try? decodeDraft(data) {
                readable.append(DraftSummary(id: id, draft: draft, hasCover: hasCover))
            } else {
                unreadable.append(DraftSummary.unreadable(id, hasCover: hasCover))
            }
        }
        readable.sort { first, second in
            let one = first.changed ?? .distantPast
            let two = second.changed ?? .distantPast
            return one != two ? one > two : first.id.raw < second.id.raw
        }
        unreadable.sort { $0.id.raw < $1.id.raw }
        return readable + unreadable
    }

    /// Decodes draft.json and keeps `project.keepingFiles` of the names in `<id>/Media`. Removes from `<id>/Media`
    /// every file that neither that project nor a project of the stored undo history names. Gives the draft with
    /// `history` nil when the project lost a clip or its music, or when a project of the history names a file that is not
    /// there. Logs each clip, music and file it takes out, and a history it drops.
    public func open(_ id: DraftID) throws -> Draft {
        guard let data = try? Data(contentsOf: draftFile(of: id)) else {
            throw DraftError.unreadable
        }
        var draft = try decodeDraft(data)
        let manager = FileManager.default
        let media = mediaFolder(of: id)
        let present = Set((try? manager.contentsOfDirectory(atPath: media.path)) ?? [])

        let kept = draft.project.keepingFiles(present)
        for clip in draft.project.clips where !kept.clips.contains(clip) {
            let file = draft.project.media[clip.media]?.fileName ?? "no facts"
            NSLog("%@", "drafts: clip \(clip.id.raw) taken out of \(id.raw), its file \(file) is not there")
        }
        if let music = draft.project.music, kept.music == nil {
            NSLog("%@", "drafts: music taken out of \(id.raw), its file \(music.file.fileName) is not there")
        }

        let past = draft.history?.past ?? []
        let future = draft.history?.future ?? []
        var named = Set(draft.project.fileNames)
        for project in past + future {
            named.formUnion(project.fileNames)
        }
        for name in present.sorted() where !named.contains(name) {
            do {
                try manager.removeItem(at: media.appendingPathComponent(name, isDirectory: false))
                NSLog("%@", "drafts: file \(name) removed from \(id.raw), no project names it")
            } catch {
                NSLog("%@", "drafts: file \(name) of \(id.raw) was not removed: \(error)")
            }
        }

        let lost = kept.clips != draft.project.clips || kept.music != draft.project.music
        if draft.history != nil, lost || !named.isSubset(of: present) {
            NSLog("%@", "drafts: the undo history of \(id.raw) dropped, it cannot be kept whole")
            draft.history = nil
        }
        draft.project = kept
        return draft
    }

    /// Removes `<folder>/<id>` whole.
    public func delete(_ id: DraftID) throws {
        do {
            try FileManager.default.removeItem(at: draftFolder(of: id))
        } catch {
            NSLog("%@", "drafts: \(id.raw) was not deleted: \(error)")
            throw DraftError.cannotWrite
        }
    }

    /// Removes `folder` whole, for -drafts fresh.
    public func removeAll() throws {
        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            NSLog("%@", "drafts: the folder of drafts was not removed: \(error)")
            throw DraftError.cannotWrite
        }
    }
}

/// A draft on the shelf that the editor has open.
public struct OpenDraft: Equatable, Sendable {
    public let shelf: DraftShelf
    public let id: DraftID

    public init(shelf: DraftShelf, id: DraftID) {
        self.shelf = shelf
        self.id = id
    }

    /// `shelf.mediaFolder(of: id)`.
    public var mediaFolder: URL {
        shelf.mediaFolder(of: id)
    }

    /// `shelf.coverFile(of: id)`.
    public var coverFile: URL {
        shelf.coverFile(of: id)
    }

    /// `encodeDraft`, then `<folder>/<id>/draft.json` written atomically: to a temporary name in the same folder,
    /// then moved over the old file, which the atomic option of `Data.write` does on Apple and on Linux alike.
    /// https://developer.apple.com/documentation/foundation/data/write(to:options:)
    public func write(_ draft: Draft) throws {
        do {
            try encodeDraft(draft).write(to: shelf.draftFile(of: id), options: .atomic)
        } catch {
            NSLog("%@", "drafts: \(id.raw) was not written: \(error)")
            throw DraftError.cannotWrite
        }
    }
}
