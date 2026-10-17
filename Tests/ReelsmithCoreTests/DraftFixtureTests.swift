import Foundation
import ReelsmithCore
import XCTest

/// Holds the shared draft fixtures of `Tests/Fixtures/Drafts/`: `swift/` as `encodeDraft` writes them and `dart/` as
/// the Dart codec writes them. With REELSMITH_WRITE_FIXTURES set the test writes each file of `swift/` that is missing,
/// never one that is there, and holds nothing else. A fixture never changes: a new field brings a new fixture.
final class DraftFixtureTests: XCTestCase {
    /// The literal of `DraftVersionOneTests`, kept as it was written.
    private let versionOne = #"{"changed":813704709,"exportSettings":{"rate":{"sixty":{}},"size":{"uhd4K":{}}},"project":{"canvas":{"landscape":{}},"clipVolume":1,"clips":[{"duration":{"ticks":1800},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0}},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0}}],"clipsMuted":false,"media":[{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080},{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920}],"music":{"fadeIn":{"ticks":0},"fadeOut":{"ticks":0},"file":{"duration":{"ticks":6000},"fileName":"long-tone.mov","id":{"raw":"long-tone"},"title":"long-tone"},"start":{"ticks":0},"volume":1},"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}"#

    /// 2026-10-14 21:05:09 in UTC.
    private let date = Date(timeIntervalSince1970: 1_792_011_909)

    private var folder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("Drafts")
    }

    /// The seed after a clip added and a text typed: an undo history of two steps, its run typing.
    private func twoSteps(_ seed: Seed) -> Draft {
        let text = TextID(seed.project.nextTextID)
        var editing = Editing(state: EditorState(project: seed.project))
        editing = editing.after(.addClips([TestClip.green.info]))
        editing = editing.after(.text(.add))
        editing = editing.after(.text(.setString(text, "Peace")))
        return Draft(
            project: editing.state.project, exportSettings: .startChoice, changed: date, history: editing.history)
    }

    /// photo-wide with blue framed, a text with every member set and 4K at 60.
    private func photoFramingText() -> Draft {
        var project = Seed.photoWide.project
        project.clips[0].framing = Framing(fit: .fill, backdrop: .blurred, zoom: 1.5, x: 0.125, y: -0.0625)
        let style = TextStyle(
            font: .naskhBold, size: 64.1, colour: RGB(r: 255, g: 214, b: 10), align: .right, lineSpacing: 0.25,
            outline: true, shadow: true, box: true)
        project.texts = [
            TextItem(
                id: TextID(1), string: "Peace\n\u{0633}\u{0644}\u{0627}\u{0645}",
                span: .range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 1200))), x: 3.857142857142857,
                y: 540.5, rotation: -45.25, style: style)
        ]
        project.nextTextID = 2
        return Draft(project: project, exportSettings: ExportSettings(size: .uhd4K, rate: .sixty), changed: date)
    }

    /// text-wide with a music whose members all differ, its text outlined and not shadowed, then the text moved: a
    /// history of one step, its run shaping.
    private func musicTextShaping() -> Draft {
        var project = Seed.textWide.project
        project.texts[0].style.outline = true
        project.texts[0].style.shadow = false
        project.music = Music(
            file: MusicFile(
                id: MediaID("evening-id"), fileName: "evening.m4a", title: "Evening", duration: Time(ticks: 9000)),
            start: Time(ticks: 600), volume: 0.45, fadeIn: Time(ticks: 300), fadeOut: Time(ticks: 900))
        let editing = Editing(state: EditorState(project: project)).after(.text(.move(TextID(1), x: 100, y: 200)))
        return Draft(
            project: editing.state.project, exportSettings: .startChoice, changed: date, history: editing.history)
    }

    /// text-wide after one drag step: a history whose run is drag.
    private func historyDrag() -> Draft {
        let editing = Editing(state: EditorState(project: Seed.textWide.project))
            .afterDragStep(.frame(.setBackdrop(ClipID(1), .blurred)))
        return Draft(
            project: editing.state.project, exportSettings: .startChoice, changed: date, history: editing.history)
    }

    /// text-wide after red deleted, the text typed and one undo: one step past, one to come, no run.
    private func historyUndone() -> Draft {
        let editing = Editing(state: EditorState(project: Seed.textWide.project))
            .after(.select(ClipID(2))).after(.deleteSelected).after(.text(.setString(TextID(1), "Peace"))).undone()
        return Draft(
            project: editing.state.project, exportSettings: .startChoice, changed: date, history: editing.history)
    }

    /// The expected draft of every fixture, by its file name.
    private func expected() -> [String: Draft] {
        var drafts = [
            "version-one.json": Draft(
                project: Seed.musicWide.project, exportSettings: ExportSettings(size: .uhd4K, rate: .sixty),
                changed: date)
        ]
        for seed in Seed.allCases {
            drafts["seed-" + seed.rawValue + ".json"] = twoSteps(seed)
        }
        drafts["photo-framing-text-4k.json"] = photoFramingText()
        drafts["music-text-shaping.json"] = musicTextShaping()
        drafts["history-drag.json"] = historyDrag()
        drafts["history-undone.json"] = historyUndone()
        return drafts
    }

    func testEveryFixtureOfBothFoldersDecodesToItsExpectedValue() throws {
        let drafts = expected()
        if ProcessInfo.processInfo.environment["REELSMITH_WRITE_FIXTURES"] != nil {
            let swift = folder.appendingPathComponent("swift")
            try FileManager.default.createDirectory(at: swift, withIntermediateDirectories: true)
            for (name, draft) in drafts
            where !FileManager.default.fileExists(atPath: swift.appendingPathComponent(name).path) {
                let data = try name == "version-one.json" ? Data(versionOne.utf8) : encodeDraft(draft)
                try data.write(to: swift.appendingPathComponent(name))
            }
            return
        }

        for side in ["swift", "dart"] {
            let sideFolder = folder.appendingPathComponent(side)
            let names = try FileManager.default.contentsOfDirectory(atPath: sideFolder.path).sorted()
            XCTAssertEqual(names, drafts.keys.sorted(), side)
            for name in names {
                let data = try Data(contentsOf: sideFolder.appendingPathComponent(name))
                XCTAssertEqual(try decodeDraft(data), drafts[name], side + "/" + name)
            }
        }
        for (name, draft) in drafts where name.hasPrefix("seed-") {
            XCTAssertEqual(draft.history?.past.count, 2, name)
        }
    }
}
