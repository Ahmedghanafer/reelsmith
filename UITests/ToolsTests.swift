import XCTest

// The split and the delete button on the seeds three-clips (blue 3 seconds, red 4, green 2)
// and two-clips (blue 3, red 4), at 60 points a second.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
@MainActor
final class ToolsTests: XCTestCase {
    func testTheTwoButtonsAreInTheToolsRegionAndDisabledAtTheStart() {
        let app = startTools(seed: "three-clips")
        let region = element(app, "editor.toolsRegion")
        let split = region.descendants(matching: .any)["editor.split"]
        let delete = region.descendants(matching: .any)["editor.delete"]

        XCTAssertTrue(split.exists)
        XCTAssertTrue(delete.exists)
        XCTAssertEqual(split.label, "Split")
        XCTAssertEqual(delete.label, "Delete")
        // The playhead is on the start of the first clip and nothing is selected.
        XCTAssertFalse(split.isEnabled)
        XCTAssertFalse(delete.isEnabled)
        // Split is the leading one.
        XCTAssertLessThan(split.frame.minX, delete.frame.minX)
        screenshot("m1-9a-split-delete-01-tools")
    }

    func testASplitAtOneSecondThenADeleteOfTheFirstBlock() {
        let app = startTools(seed: "three-clips", playhead: 600)
        let split = element(app, "editor.split")
        let delete = element(app, "editor.delete")
        XCTAssertTrue(split.isEnabled)
        XCTAssertFalse(delete.isEnabled)

        // The blue clip becomes a part of 1 second and a part of 2 seconds.
        split.tap()
        assertTheBlocks(app, widths: [60, 120, 240, 120])
        XCTAssertEqual(playheadValue(app), "00:01")
        XCTAssertFalse(delete.isEnabled)
        screenshot("m1-9a-split-delete-02-after-split")

        // The first block ends under the playhead, so its middle is on the screen.
        element(app, "editor.clip.1").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element(app, "editor.clip.1").isSelected)
        XCTAssertTrue(delete.isEnabled)

        delete.tap()
        // No question is asked: the block is gone at once.
        assertTheBlocks(app, widths: [120, 240, 120])
        XCTAssertFalse(delete.isEnabled)
        screenshot("m1-9a-split-delete-03-after-delete")
    }

    func testDeletingEveryClipLeavesTheEmptyEditor() {
        let app = startTools(seed: "two-clips")
        let split = element(app, "editor.split")
        let delete = element(app, "editor.delete")

        // After the first delete the red clip is the first block.
        for remaining in [1, 0] {
            let first = element(app, "editor.clip.1")
            XCTAssertTrue(first.exists)
            first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(delete.isEnabled)
            delete.tap()
            XCTAssertEqual(element(app, "editor.clip.1").exists, remaining == 1)
        }

        XCTAssertFalse(element(app, "editor.clip.1").exists)
        XCTAssertFalse(split.isEnabled)
        XCTAssertFalse(delete.isEnabled)
        let info = app.staticTexts["editor.seedInfo"].label
        XCTAssertTrue(info.hasPrefix("0 clips"), info)
        screenshot("m1-9a-split-delete-04-empty")
    }

    func testInArabicTheRowMirrorsAndShowsItsArabicWords() {
        let app = startTools(seed: "three-clips", language: "ar")
        let split = element(app, "editor.split")
        let delete = element(app, "editor.delete")

        XCTAssertTrue(split.exists)
        XCTAssertTrue(delete.exists)
        // The Arabic lines of the word file.
        XCTAssertEqual(split.label, "تقسيم")
        XCTAssertEqual(delete.label, "حذف")
        // Split is still the leading one, which is now on the right.
        XCTAssertGreaterThan(split.frame.minX, delete.frame.minX)
        screenshot("m1-9a-split-delete-01-tools-ar")
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startTools(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        XCTAssertTrue(element(app, "editor.root").waitForExistence(timeout: 60))
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// As many blocks as widths, in track order from left to right, touching, each that many points wide,
    /// and none of them selected.
    private func assertTheBlocks(_ app: XCUIApplication, widths: [Double]) {
        let blocks = (1...widths.count).map { element(app, "editor.clip." + String($0)) }
        for block in blocks {
            XCTAssertTrue(block.exists)
        }
        XCTAssertFalse(element(app, "editor.clip." + String(widths.count + 1)).exists)
        guard blocks.allSatisfy({ $0.exists }) else {
            return
        }
        let frames = blocks.map { $0.frame }
        for (index, width) in widths.enumerated() {
            XCTAssertEqual(Double(frames[index].width), width, accuracy: 1)
            XCTAssertFalse(blocks[index].isSelected)
            if index > 0 {
                XCTAssertEqual(frames[index - 1].maxX, frames[index].minX, accuracy: 1)
            }
        }
    }
}
