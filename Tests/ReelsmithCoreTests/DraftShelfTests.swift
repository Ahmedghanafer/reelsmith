import Foundation
import ReelsmithCore
import XCTest

/// Holds the shelf of drafts in a folder: create, list, open with its repair, write, delete and removeAll.
/// Each test works in a new folder under the temporary folder, named by a UUID, removed at its end.
final class DraftShelfTests: XCTestCase {
    /// 2026-10-14 00:00:00 in UTC.
    private let midnight = Date(timeIntervalSince1970: 1_791_936_000)
    /// A shelf on a folder that is not there yet, inside a new folder that is removed at the end of the test.
    private func makeShelf() -> DraftShelf {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return DraftShelf(folder: root.appendingPathComponent("Drafts", isDirectory: true))
    }

    private func at(hour: Int) -> Date {
        midnight.addingTimeInterval(TimeInterval(hour * 3600))
    }

    private func draft(_ seed: Seed, hour: Int = 10) -> Draft {
        Draft(project: seed.project, exportSettings: .startChoice, changed: at(hour: hour))
    }

    private func folder(of id: DraftID, in shelf: DraftShelf) -> URL {
        shelf.folder.appendingPathComponent(id.raw, isDirectory: true)
    }

    /// A media file: a few bytes under the name the project gives.
    private func put(_ names: [String], in folder: URL) throws {
        for name in names {
            try Data([1, 2, 3]).write(to: folder.appendingPathComponent(name, isDirectory: false))
        }
    }

    private func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    /// A folder in the shelf with a draft.json that holds the text given, or none for nil.
    private func odd(_ text: String?, in shelf: DraftShelf) throws -> DraftID {
        let id = DraftID(UUID().uuidString)
        let place = folder(of: id, in: shelf)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        if let text {
            try Data(text.utf8).write(to: place.appendingPathComponent("draft.json", isDirectory: false))
        }
        return id
    }

    func testCreateMakesTheFoldersAndOpenGivesTheDraft() throws {
        let shelf = makeShelf()
        XCTAssertFalse(FileManager.default.fileExists(atPath: shelf.folder.path))
        let made = draft(.twoClipsWide)

        let open = try shelf.create(made)
        try put(["blue.mov", "red.mov"], in: open.mediaFolder)

        XCTAssertEqual(open.mediaFolder.path, shelf.folder.path + "/" + open.id.raw + "/Media")
        XCTAssertEqual(open.coverFile.path, shelf.folder.path + "/" + open.id.raw + "/cover.jpg")
        var isFolder: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: open.mediaFolder.path, isDirectory: &isFolder))
        XCTAssertTrue(isFolder.boolValue)
        XCTAssertEqual(try shelf.open(open.id), made)
        XCTAssertNotEqual(try shelf.create(made).id, open.id)
    }

    func testAFolderThatIsNotThereListsNone() {
        let shelf = makeShelf()
        XCTAssertEqual(shelf.list(), [])
    }

    func testTheListIsNewestFirstThenTheUnreadableByID() throws {
        let shelf = makeShelf()
        let ten = try shelf.create(draft(.twoClipsWide, hour: 10))
        let twelve = try shelf.create(draft(.textWide, hour: 12))
        let eleven = try shelf.create(draft(.musicWide, hour: 11))
        try put(["cover.jpg"], in: folder(of: eleven.id, in: shelf))
        let unreadable = [try odd(nil, in: shelf), try odd("broken", in: shelf)].sorted { $0.raw < $1.raw }

        let list = shelf.list()

        XCTAssertEqual(list.map(\.id), [twelve.id, eleven.id, ten.id] + unreadable)
        XCTAssertEqual(list.map(\.changed), [at(hour: 12), at(hour: 11), at(hour: 10), nil, nil])
        XCTAssertEqual(list.map(\.hasCover), [false, true, false, false, false])
        XCTAssertEqual(list[0], DraftSummary(id: twelve.id, draft: draft(.textWide, hour: 12), hasCover: false))
        XCTAssertEqual(list[3], DraftSummary.unreadable(unreadable[0], hasCover: false))
        XCTAssertEqual(list[4], DraftSummary.unreadable(unreadable[1], hasCover: false))
    }

    func testOpenTakesOutTheClipsAndTheMusicWhoseFilesAreMissing() throws {
        let shelf = makeShelf()
        let open = try shelf.create(draft(.musicWide))
        try put(["blue.mov"], in: open.mediaFolder)

        let project = try shelf.open(open.id).project

        XCTAssertEqual(project.clips.map(\.media), [TestClip.blue.info.id])
        XCTAssertEqual(project.clips, [Seed.musicWide.project.clips[0]])
        XCTAssertNil(project.music)
        XCTAssertEqual(try names(in: open.mediaFolder), ["blue.mov"])
    }

    func testOpenRemovesAFileTheProjectDoesNotName() throws {
        let shelf = makeShelf()
        let made = draft(.musicWide)
        let open = try shelf.create(made)
        try put(["blue.mov", "red.mov", "long-tone.mov", "old.mov"], in: open.mediaFolder)

        XCTAssertEqual(try shelf.open(open.id), made)
        XCTAssertEqual(try names(in: open.mediaFolder), ["blue.mov", "long-tone.mov", "red.mov"])
    }

    func testAnUnreadableDraftDoesNotOpenAndLosesNoFile() throws {
        let shelf = makeShelf()
        for text in [nil, "broken"] {
            let id = try odd(text, in: shelf)
            let media = shelf.mediaFolder(of: id)
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
            try put(["blue.mov", "old.mov"], in: media)
            let before = try names(in: folder(of: id, in: shelf))

            XCTAssertThrowsError(try shelf.open(id)) { error in
                XCTAssertEqual(error as? DraftError, .unreadable)
            }
            XCTAssertEqual(try names(in: folder(of: id, in: shelf)), before)
            XCTAssertEqual(try names(in: media), ["blue.mov", "old.mov"])
        }
    }

    func testTheSecondOfTwoWritesStaysAndNothingElseChanges() throws {
        let shelf = makeShelf()
        let open = try shelf.create(draft(.twoClipsWide))
        let file = open.mediaFolder.appendingPathComponent("blue.mov", isDirectory: false)
        try Data([7, 8, 9]).write(to: file)
        try put(["red.mov"], in: open.mediaFolder)
        let first = draft(.textWide, hour: 11)
        let second = draft(.musicWide, hour: 12)

        try open.write(first)
        try open.write(second)

        let json = folder(of: open.id, in: shelf).appendingPathComponent("draft.json", isDirectory: false)
        XCTAssertEqual(try decodeDraft(try Data(contentsOf: json)), second)
        XCTAssertEqual(try names(in: folder(of: open.id, in: shelf)), ["Media", "draft.json"])
        XCTAssertEqual(try names(in: open.mediaFolder), ["blue.mov", "red.mov"])
        XCTAssertEqual(try Data(contentsOf: file), Data([7, 8, 9]))
        XCTAssertEqual(
            try Data(contentsOf: open.mediaFolder.appendingPathComponent("red.mov", isDirectory: false)),
            Data([1, 2, 3]))
    }

    func testDeleteRemovesOneDraftAndRemoveAllTheShelf() throws {
        let shelf = makeShelf()
        let gone = try shelf.create(draft(.twoClipsWide, hour: 10))
        let kept = try shelf.create(draft(.textWide, hour: 11))
        try put(["blue.mov"], in: gone.mediaFolder)
        try put(["cover.jpg"], in: folder(of: gone.id, in: shelf))

        try shelf.delete(gone.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: folder(of: gone.id, in: shelf).path))
        XCTAssertEqual(shelf.list().map(\.id), [kept.id])
        XCTAssertThrowsError(try shelf.delete(gone.id)) { error in
            XCTAssertEqual(error as? DraftError, .cannotWrite)
        }

        try shelf.removeAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: shelf.folder.path))
        XCTAssertEqual(shelf.list(), [])
    }

    func testOpenKeepsTheFilesAndTheHistoryOfAnUndo() throws {
        let shelf = makeShelf()
        let edited = deletedRed()
        let made = Draft(
            project: edited.state.project, exportSettings: .startChoice, changed: at(hour: 10),
            history: edited.history)
        let open = try shelf.create(made)
        try put(["blue.mov", "red.mov"], in: open.mediaFolder)

        let opened = try shelf.open(open.id)

        XCTAssertEqual(opened, made)
        XCTAssertEqual(opened.history, edited.history)
        XCTAssertEqual(try names(in: open.mediaFolder), ["blue.mov", "red.mov"])
    }

    func testOpenDropsAHistoryThatNamesAMissingFile() throws {
        let shelf = makeShelf()
        let edited = deletedRed()
        let open = try shelf.create(
            Draft(
                project: edited.state.project, exportSettings: .startChoice, changed: at(hour: 10),
                history: edited.history))
        try put(["blue.mov"], in: open.mediaFolder)

        let opened = try shelf.open(open.id)

        XCTAssertNil(opened.history)
        XCTAssertEqual(opened.project, edited.state.project)
        XCTAssertEqual(try names(in: open.mediaFolder), ["blue.mov"])
    }

    /// two-clips-wide with red deleted through the editing, so the history holds that delete.
    private func deletedRed() -> Editing {
        let project = Seed.twoClipsWide.project
        let red = project.clips.first { $0.media == TestClip.red.info.id }!.id
        let edited = Editing(state: EditorState(project: project)).after(.select(red)).after(.deleteSelected)
        XCTAssertEqual(edited.state.project.fileNames, ["blue.mov"])
        XCTAssertTrue(edited.history.past.contains { $0.fileNames.contains("red.mov") })
        return edited
    }

    /// E15: the bytes of draft.json and the milliseconds of 100 writes, printed with no assertion.
    func testE15PrintsTheBytesAndTheTimeOfAWrite() throws {
        let shelf = makeShelf()
        for seed in [Seed.textWide, Seed.musicWide] {
            let made = draft(seed)
            let open = try shelf.create(made)
            let bytes = try encodeDraft(made).count
            let start = Date()
            for _ in 0..<100 {
                try open.write(made)
            }
            let milliseconds = Int((Date().timeIntervalSince(start) * 1000).rounded())
            print(
                "E15 " + seed.rawValue + ": " + String(bytes) + " bytes, 100 writes in " + String(milliseconds)
                    + " ms")
        }
    }
}
