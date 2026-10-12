import ReelsmithCore
import XCTest

final class ExportStateTests: XCTestCase {
    func testIdleGivesNoWordsAndNoPercent() {
        XCTAssertNil(ExportState.idle.words)
        XCTAssertNil(ExportState.idle.percentText)
    }

    func testExportingGivesTheKeyOfExportingAndStartsAtZeroPercent() {
        let exporting = ExportState.idle.after(.started)

        XCTAssertEqual(exporting.words, Words("export.exporting"))
        XCTAssertEqual(exporting.percentText, "0%")
    }

    func testThePercentFollowsTheProgress() {
        let exporting = ExportState.idle.after(.started)

        XCTAssertEqual(exporting.after(.progress(0.42)).percentText, "42%")
        XCTAssertEqual(exporting.after(.progress(1)).percentText, "100%")
    }

    func testThePercentNeverGoesDownWhenALowerProgressArrives() {
        let half = ExportState.idle.after(.started).after(.progress(0.5))

        XCTAssertEqual(half.after(.progress(0.25)).percentText, "50%")
        XCTAssertEqual(half.after(.progress(0.25)).after(.progress(0.75)).percentText, "75%")
    }

    func testThePercentIsWrittenWithTheDigitsZeroToNineFromZeroToAHundred() {
        let exporting = ExportState.idle.after(.started)

        XCTAssertEqual(exporting.after(.progress(-1)).percentText, "0%")
        XCTAssertEqual(exporting.after(.progress(7)).percentText, "100%")
        for step in 0...20 {
            let text = exporting.after(.progress(Double(step) / 20)).percentText ?? ""
            XCTAssertTrue(text.hasSuffix("%"), text)
            XCTAssertFalse(text.dropLast().isEmpty, text)
            XCTAssertTrue(text.dropLast().allSatisfy { "0123456789".contains($0) }, text)
        }
    }

    func testAProgressValueThatIsNotANumberChangesNothing() {
        let half = ExportState.idle.after(.started).after(.progress(0.5))

        XCTAssertEqual(half.after(.progress(.nan)), half)
        XCTAssertEqual(half.after(.progress(.infinity)).percentText, "100%")
    }

    func testSavedGivesTheKeyOfSavedAndNoPercent() {
        let saved = ExportState.idle.after(.started).after(.saved)

        XCTAssertEqual(saved, .saved)
        XCTAssertEqual(saved.words, Words("export.saved"))
        XCTAssertNil(saved.percentText)
    }

    func testFailedGivesTheKeyOfFailedOrOfNotAllowed() {
        let exporting = ExportState.idle.after(.started)
        let failed = exporting.after(.failed(notAllowed: false))
        let refused = exporting.after(.failed(notAllowed: true))

        XCTAssertEqual(failed, .failed(notAllowed: false))
        XCTAssertEqual(failed.words, Words("export.failed"))
        XCTAssertNil(failed.percentText)
        XCTAssertEqual(refused, .failed(notAllowed: true))
        XCTAssertEqual(refused.words, Words("export.notAllowed"))
    }

    func testAllWordsListsExactlyTheFourKeys() {
        XCTAssertEqual(
            ExportState.allWords, ["export.exporting", "export.saved", "export.failed", "export.notAllowed"])
    }

    func testClosingTheSavedOrTheFailedCaseGivesIdle() {
        XCTAssertEqual(ExportState.saved.after(.closed), .idle)
        XCTAssertEqual(ExportState.failed(notAllowed: false).after(.closed), .idle)
        XCTAssertEqual(ExportState.failed(notAllowed: true).after(.closed), .idle)
    }

    func testAnEventWithNoMeaningInACaseLeavesItUnchanged() {
        let exporting = ExportState.idle.after(.started).after(.progress(0.5))
        let failed = ExportState.failed(notAllowed: false)

        XCTAssertEqual(ExportState.idle.after(.progress(0.5)), .idle)
        XCTAssertEqual(ExportState.idle.after(.saved), .idle)
        XCTAssertEqual(ExportState.idle.after(.failed(notAllowed: false)), .idle)
        XCTAssertEqual(ExportState.idle.after(.closed), .idle)
        XCTAssertEqual(exporting.after(.started), exporting)
        XCTAssertEqual(exporting.after(.closed), exporting)
        // A progress value that arrives after the end changes nothing.
        XCTAssertEqual(ExportState.saved.after(.progress(1)), .saved)
        XCTAssertEqual(ExportState.saved.after(.started), .saved)
        XCTAssertEqual(ExportState.saved.after(.failed(notAllowed: false)), .saved)
        XCTAssertEqual(failed.after(.progress(1)), failed)
        XCTAssertEqual(failed.after(.started), failed)
        XCTAssertEqual(failed.after(.saved), failed)
    }

    func testTheExportCanStartExactlyWhenTheEditorCanExportAndTheStateIsIdle() {
        let filled = EditorState(project: Seed.twoClips.project)
        let empty = EditorState(project: Seed.empty.project)
        let exporting = ExportState.idle.after(.started)

        XCTAssertTrue(filled.canExport)
        XCTAssertFalse(empty.canExport)
        XCTAssertTrue(ExportState.idle.canStart(filled))
        XCTAssertFalse(ExportState.idle.canStart(empty))
        XCTAssertFalse(exporting.canStart(filled))
        XCTAssertFalse(ExportState.saved.canStart(filled))
        XCTAssertFalse(ExportState.failed(notAllowed: false).canStart(filled))
        XCTAssertFalse(ExportState.failed(notAllowed: true).canStart(filled))
    }
}
