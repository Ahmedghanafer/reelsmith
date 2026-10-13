import XCTest

// The export button and its panel on the seeds two-clips (7 seconds), empty and two-clips-wide.
// The class has a name of its own, because the Engine tests hold a class ExportTests.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielement/ishittable
// https://developer.apple.com/documentation/xctest/xcuielementquery/count
// https://developer.apple.com/documentation/xctest/xcuiapplication/init(bundleidentifier:)
@MainActor
final class ExportPanelTests: XCTestCase {
    /// An export of 7 seconds with its save, in seconds. The wait fails at three times this.
    private let expectedSaved = 20.0
    /// The failed panel comes before any work.
    private let expectedFailed = 5.0

    func testTheExportButtonIsTheOneButtonOfItsRegionAndEnabledOnAProject() {
        let app = startExport(seed: "two-clips")
        let region = element(app, "editor.exportRegion")
        let export = region.descendants(matching: .any)["editor.export"]

        XCTAssertTrue(export.exists)
        XCTAssertEqual(region.descendants(matching: .button).count, 1)
        XCTAssertEqual(export.label, "Export")
        XCTAssertTrue(export.isEnabled)
        XCTAssertFalse(element(app, "export.words").exists)
        screenshot("m1-10-export-01-button")
    }

    func testOnTheEmptyProjectTheExportButtonIsDisabled() {
        let app = startExport(seed: "empty")
        let export = element(app, "editor.export")

        XCTAssertTrue(export.exists)
        XCTAssertFalse(export.isEnabled)
        screenshot("m1-10-export-02-empty")
    }

    func testAnExportReachesTheSavedPanelAndDoneReturnsToTheEditorAsItWas() {
        let app = startExport(seed: "two-clips", playhead: 600)
        let export = element(app, "editor.export")

        mark("m1-10-export-01-export")
        export.tap()
        let done = waitForTheButton(app, "export.done", expected: expectedSaved)
        XCTAssertEqual(element(app, "export.words").label, "Saved to Photos")
        XCTAssertEqual(done.label, "Done")
        XCTAssertFalse(element(app, "export.close").exists)
        assertNothingBehindThePanelCanBeTouched(app)
        screenshot("m1-10-export-03-saved")

        done.tap()
        XCTAssertTrue(waitUntilHittable(export))
        XCTAssertTrue(export.isEnabled)
        XCTAssertFalse(element(app, "export.words").exists)
        // The state is as it was: the two clips and the playhead of the start.
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        XCTAssertFalse(element(app, "editor.clip.3").exists)
        XCTAssertEqual(element(app, "editor.playhead").value as? String, "00:01")
    }

    func testInArabicTheSavedPanelShowsItsArabicWords() {
        let app = startExport(seed: "two-clips", language: "ar")

        element(app, "editor.export").tap()
        let done = waitForTheButton(app, "export.done", expected: expectedSaved)
        // The Arabic lines of the word file.
        XCTAssertEqual(element(app, "export.words").label, "تم الحفظ في الصور")
        XCTAssertEqual(done.label, "تم")
        screenshot("m1-10-export-03-saved-ar")
    }

    func testWithExportFailsThePanelShowsFailedAndCloseReturnsToTheEditor() {
        let app = startExport(seed: "two-clips", exportFails: true)
        let export = element(app, "editor.export")

        export.tap()
        let close = waitForTheButton(app, "export.close", expected: expectedFailed)
        XCTAssertEqual(element(app, "export.words").label, "Export failed. Nothing was saved.")
        XCTAssertEqual(close.label, "Close")
        XCTAssertFalse(element(app, "export.done").exists)
        assertNothingBehindThePanelCanBeTouched(app)
        screenshot("m1-10-export-04-failed")

        close.tap()
        XCTAssertTrue(waitUntilHittable(export))
        XCTAssertTrue(export.isEnabled)
        XCTAssertFalse(element(app, "export.words").exists)
    }

    func testOnTheWideSeedAnExportReachesTheSavedPanel() {
        let app = startExport(seed: "two-clips-wide")

        element(app, "editor.export").tap()
        _ = waitForTheButton(app, "export.done", expected: expectedSaved)
        XCTAssertEqual(element(app, "export.words").label, "Saved to Photos")
        screenshot("m1-10-export-05-saved-wide")
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startExport(
        seed: String, language: String = "en", playhead: Int? = nil, exportFails: Bool = false
    ) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead, exportFails: exportFails)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Waits for a button of the panel, prints the seconds it took and fails only at three times the expected value.
    /// A question of the system is answered with its last button and named in the test log.
    private func waitForTheButton(_ app: XCUIApplication, _ identifier: String, expected: Double) -> XCUIElement {
        let button = element(app, identifier)
        let question = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        let start = Date()
        while !button.waitForExistence(timeout: 1) && Date().timeIntervalSince(start) < expected * 3 {
            if question.exists {
                print("m1-10-export: the system asked a question during the export: " + question.label)
                question.buttons.element(boundBy: question.buttons.count - 1).tap()
            }
        }
        let took = Date().timeIntervalSince(start)
        print("m1-10-export: " + identifier + " after " + String(format: "%.1f", took) + " seconds, expected "
            + String(expected) + ", limit " + String(expected * 3))
        XCTAssertTrue(button.exists, identifier + " did not come within " + String(expected * 3) + " seconds")
        return button
    }

    /// The panel covers the editor: a control of the tools and the export button are not there to be touched.
    private func assertNothingBehindThePanelCanBeTouched(_ app: XCUIApplication) {
        for identifier in ["editor.export", "editor.split", "editor.clip.1"] {
            let behind = element(app, identifier)
            XCTAssertFalse(behind.exists && behind.isHittable, identifier + " can be touched behind the panel")
        }
    }

    /// The panel leaves with a movement, so the editor is waited for.
    private func waitUntilHittable(_ element: XCUIElement) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < 10 {
            if element.exists && element.isHittable {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }
}
