import XCTest

@MainActor
final class HarnessTests: XCTestCase {
    func testASeedStartOpensTheShellAndWritesItsClips() {
        mark("m1-2b-ui-harness-01-launch")
        let app = startApp(seed: "two-clips")

        // The seed start writes two clips first, which takes a while in a simulator.
        waitForTheEditor(app)
        let regions = ["editor.previewRegion", "editor.timelineRegion", "editor.toolsRegion", "editor.exportRegion"]
            .map { app.descendants(matching: .any)[$0] }
        for region in regions {
            XCTAssertTrue(region.exists)
        }
        if regions.allSatisfy({ $0.exists }) {
            // From top to bottom.
            XCTAssertLessThan(regions[0].frame.minY, regions[1].frame.minY)
            XCTAssertLessThan(regions[1].frame.minY, regions[2].frame.minY)
            XCTAssertLessThan(regions[2].frame.minY, regions[3].frame.minY)
        }

        let info = app.staticTexts["editor.seedInfo"].label
        XCTAssertTrue(info.hasPrefix("2 clips, "), info)
        let files = Int(info.dropFirst("2 clips, ".count).prefix(while: { $0.isNumber })) ?? 0
        XCTAssertGreaterThanOrEqual(files, 2, info)
        screenshot("m1-2b-ui-harness-01-shell")
    }

    func testWithNoSeedTheStartSlotShows() {
        let app = startApp(seed: nil)

        assertTheStartSlotShows(app)
        screenshot("m1-2b-ui-harness-02-no-seed")
    }

    func testAnUnknownSeedNameOpensAsWithNoSeed() {
        let app = startApp(seed: "four-clips")

        assertTheStartSlotShows(app)
    }

    func testAStartInSwedishWithAPlayheadAndAnExportFailureOpensTheShellInSwedish() {
        let app = startApp(seed: "two-clips", language: "sv", playhead: 3000, exportFails: true)

        waitForTheEditor(app)
        // The seed text is the Swedish line of the word file, so the language reached the app.
        let info = app.staticTexts["editor.seedInfo"].label
        XCTAssertTrue(info.hasPrefix("2 klipp, "), info)
        screenshot("m1-2b-ui-harness-02-shell-sv")
    }

    func testAStartInArabicOpensTheShellInArabic() {
        let app = startApp(seed: "two-clips", language: "ar")

        waitForTheEditor(app)
        // The Arabic line of the word file with both numbers in it.
        let info = app.staticTexts["editor.seedInfo"].label
        XCTAssertTrue(info.contains("المقاطع: 2"), info)
        XCTAssertTrue(info.contains("الملفات: 2"), info)
        screenshot("m1-2b-ui-harness-01-shell-ar")
    }

    /// The content of the slot `start` is some text, and the editor with its seed text is not there.
    private func assertTheStartSlotShows(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 30))
        XCTAssertFalse(app.descendants(matching: .any)["editor.root"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["editor.seedInfo"].exists)
    }
}
