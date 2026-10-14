import Foundation
import ReelsmithCore
import XCTest

/// Holds the stored form of a project: `Draft`, its coding, the files a project names, the summary and its lines.
final class DraftTests: XCTestCase {
    /// 2026-10-14 21:05:09 in UTC.
    private let date = Date(timeIntervalSince1970: 1_792_011_909)
    private let utc = TimeZone(identifier: "UTC")!

    private func roundTrip(_ draft: Draft) throws -> Draft {
        try decodeDraft(try encodeDraft(draft))
    }

    func testADraftOfEverySeedRoundTripsAtVersionOne() throws {
        XCTAssertEqual(Seed.allCases.count, 7)
        for seed in Seed.allCases {
            let draft = Draft(project: seed.project, exportSettings: .startChoice, changed: date)

            XCTAssertEqual(draft.version, 1, seed.rawValue)
            XCTAssertEqual(try roundTrip(draft), draft, seed.rawValue)
        }
        XCTAssertEqual(Draft.version, 1)
    }

    func testTheArabicLineAndTheLineBreakOfTextWideComeBack() throws {
        let draft = Draft(project: Seed.textWide.project, exportSettings: .startChoice, changed: date)
        let string = try XCTUnwrap(try roundTrip(draft).project.texts.first?.string)

        XCTAssertEqual(string, Seed.textWide.project.texts[0].string)
        XCTAssertEqual(string.split(separator: "\n").count, 3)
        XCTAssertEqual(Array(string.unicodeScalars), Array(Seed.textWide.project.texts[0].string.unicodeScalars))
    }

    func testNumbersOfATextComeBackExactly() throws {
        var project = Seed.textWide.project
        project.texts[0].x = 3.857142857142857
        project.texts[0].style.size = 64.1
        let back = try roundTrip(Draft(project: project, exportSettings: .startChoice, changed: date))

        XCTAssertEqual(back.project, project)
        XCTAssertEqual(back.project.texts[0].x, 3.857142857142857)
        XCTAssertEqual(back.project.texts[0].style.size, 64.1)
    }

    func testTheSettingsAndTheDateComeBack() throws {
        let settings = ExportSettings(size: .uhd4K, rate: .sixty)
        let back = try roundTrip(Draft(project: Seed.twoClipsWide.project, exportSettings: settings, changed: date))

        XCTAssertEqual(back.exportSettings, settings)
        XCTAssertEqual(back.changed, date)
    }

    func testBytesThatAreNotADraftAreUnreadable() throws {
        var wide = Draft(project: Seed.twoClipsWide.project, exportSettings: .startChoice, changed: date)
        wide.version = 2
        let inputs = [Data("not json".utf8), Data("{\"a\":1}".utf8), try encodeDraft(wide)]

        for data in inputs {
            XCTAssertThrowsError(try decodeDraft(data)) { error in
                XCTAssertEqual(error as? DraftError, .unreadable)
            }
        }
    }

    func testFileNamesAreTheFilesTheClipsAndTheMusicUse() {
        XCTAssertEqual(Seed.twoClipsWide.project.fileNames, ["blue.mov", "red.mov"])
        XCTAssertEqual(Seed.musicWide.project.fileNames, ["blue.mov", "long-tone.mov", "red.mov"])
        XCTAssertEqual(Seed.empty.project.fileNames, [])

        var state = EditorState(project: Seed.musicWide.project)
        state = reduce(state, .select(ClipID(2)))
        state = reduce(state, .deleteSelected)

        XCTAssertNotNil(state.project.media[MediaID("red")])
        XCTAssertEqual(state.project.fileNames, ["blue.mov", "long-tone.mov"])
    }

    func testKeepingFilesTakesOutWhatIsMissing() {
        let project = Seed.musicWide.project
        let blue = project.clips[0]
        let blueInfo = TestClip.blue.info

        let noRed = project.keepingFiles(["blue.mov", "long-tone.mov"])
        XCTAssertEqual(noRed.clips, [blue])
        XCTAssertEqual(noRed.media, [blueInfo.id: blueInfo])
        XCTAssertEqual(noRed.music, project.music)

        let noTone = project.keepingFiles(["blue.mov", "red.mov"])
        XCTAssertEqual(noTone.clips, project.clips)
        XCTAssertEqual(noTone.media, project.media)
        XCTAssertNil(noTone.music)

        let none = project.keepingFiles([])
        XCTAssertEqual(none.clips, [])
        XCTAssertEqual(none.media, [:])
        XCTAssertNil(none.music)

        for kept in [noRed, noTone, none] {
            XCTAssertEqual(kept.canvas, project.canvas)
            XCTAssertEqual(kept.clipVolume, project.clipVolume)
            XCTAssertEqual(kept.clipsMuted, project.clipsMuted)
            XCTAssertEqual(kept.nextClipID, project.nextClipID)
        }

        let text = Seed.textWide.project
        for present in [Set(["blue.mov", "red.mov"]), Set(["blue.mov"]), Set<String>()] {
            let kept = text.keepingFiles(present)
            XCTAssertEqual(kept.texts, text.texts)
            XCTAssertEqual(kept.nextTextID, text.nextTextID)
            XCTAssertEqual(kept.canvas, text.canvas)
            XCTAssertEqual(kept.clipVolume, text.clipVolume)
            XCTAssertEqual(kept.clipsMuted, text.clipsMuted)
            XCTAssertEqual(kept.nextClipID, text.nextClipID)
        }
    }

    func testTheSummaryOfADraft() {
        let settings = ExportSettings(size: .hd720, rate: .sixty)
        let draft = Draft(project: Seed.textWide.project, exportSettings: settings, changed: date)
        let summary = DraftSummary(id: DraftID("A"), draft: draft, hasCover: true)

        XCTAssertEqual(summary.id, DraftID("A"))
        XCTAssertEqual(summary.duration, Time(ticks: 4200))
        XCTAssertEqual(summary.clipCount, 2)
        XCTAssertEqual(summary.textCount, 1)
        XCTAssertEqual(summary.exportSettings, settings)
        XCTAssertEqual(summary.changed, date)
        XCTAssertTrue(summary.hasCover)
        XCTAssertTrue(summary.isReadable)
    }

    func testTheSummaryOfAnUnreadableDraft() {
        let summary = DraftSummary.unreadable(DraftID("B"), hasCover: false)

        XCTAssertEqual(summary.id, DraftID("B"))
        XCTAssertNil(summary.changed)
        XCTAssertEqual(summary.duration, .zero)
        XCTAssertEqual(summary.clipCount, 0)
        XCTAssertEqual(summary.textCount, 0)
        XCTAssertEqual(summary.exportSettings, .standard)
        XCTAssertFalse(summary.hasCover)
        XCTAssertFalse(summary.isReadable)
    }

    func testDateText() {
        XCTAssertEqual(dateText(date, in: utc), "2026-10-14 21:05")
        XCTAssertEqual(dateText(Date(timeIntervalSince1970: 1_767_323_040), in: utc), "2026-01-02 03:04")

        let digits = Set("0123456789 -:")
        XCTAssertTrue(dateText(date, in: utc).allSatisfy { digits.contains($0) })
    }

    func testDraftsInfo() {
        var short = Project(canvas: .landscape)
        let blue = TestClip.blue.info
        short.media[blue.id] = blue
        short.clips = [Clip(id: ClipID(1), media: blue.id, sourceStart: .zero, duration: blue.duration)]
        short.nextClipID = 2
        short.texts = Seed.textWide.project.texts
        short.nextTextID = 2
        let first = DraftSummary(
            id: DraftID("A"), draft: Draft(project: short, exportSettings: ExportSettings(size: .hd720, rate: .sixty), changed: date),
            hasCover: true)
        let second = DraftSummary(
            id: DraftID("B"), draft: Draft(project: Seed.twoClipsWide.project, exportSettings: .standard, changed: date),
            hasCover: false)

        XCTAssertEqual(draftsInfo([]), "0")
        XCTAssertEqual(draftsInfo([first, second]), "2 1+1800+1+720x60+c 2+4200+0+1080x30+.")
        XCTAssertEqual(draftsInfo([.unreadable(DraftID("C"), hasCover: true)]), "1 x")
    }
}
