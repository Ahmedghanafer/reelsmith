import XCTest

// The export choice kept with its draft, on the seed two-clips-wide: blue for 3 seconds then red for 4 on the
// landscape canvas. The choice is read through the label of `editor.exportSettings`, and the stored draft only
// through the line `start.draftsInfo` after a launch with `-drafts kept` and no seed. Each test starts its first
// launch with `-drafts fresh`, which empties the test folder of drafts.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/init(bundleidentifier:)
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class ExportKeptTests: XCTestCase {
    /// The export of 7 seconds at 720p and 60 with its save, taken as the first export of its run, in seconds.
    private let expectedSaved = 45.0
    /// The sheet is expected within 10 seconds of the tap at most, three times this.
    private let expectedSheet = 10.0 / 3

    func testTheChoiceIsWrittenWithTheDraft() {
        let app = startSeeded(language: "en")
        let choice = element(app, "editor.exportSettings")
        assertTheLabel(choice, holds: "1080p", "30 fps")

        choose(app, "export.size.uhd4K", "export.rate.sixty")
        assertTheLabel(choice, holds: "4K", "60 fps")
        screenshot("export-kept-01-chosen")
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 2+4200+0+2160x60+.")
    }

    func testInArabic() {
        let app = startSeeded(language: "ar")
        choose(app, "export.size.uhd4K", "export.rate.sixty")
        screenshot("export-kept-01-chosen-ar")
    }

    func testInSwedish() {
        let app = startSeeded(language: "sv")
        choose(app, "export.size.uhd4K", "export.rate.sixty")
        screenshot("export-kept-01-chosen-sv")
    }

    func testAnUndoLeavesTheChoice() {
        let app = startSeeded(language: "en", playhead: 1200)
        choose(app, "export.size.hd720", "export.rate.sixty")

        // At 2 seconds, inside blue, the first quarter of red is on the screen.
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        element(app, "editor.delete").tap()
        waitUntil("one block after the delete") { !red.exists }
        element(app, "editor.undo").tap()
        waitUntil("two blocks after the undo") { self.element(app, "editor.clip.2").exists }

        assertTheLabel(element(app, "editor.exportSettings"), holds: "720p", "60 fps")
    }

    func testTheExportIsAtTheChoice() {
        let app = startSeeded(language: "en")
        choose(app, "export.size.hd720", "export.rate.sixty")

        mark("export-kept-01-export")
        element(app, "editor.export").tap()
        _ = waitForTheButton(app, "export.done", expected: expectedSaved)
        XCTAssertEqual(element(app, "export.fileInfo").label, "1280 720 60")
    }

    /// A draft at 4K and 60 is in the test folder, and a seeded start without `-drafts` still starts at the start
    /// choice.
    func testWithoutDraftsTheStartIsTheStartChoice() {
        var app = startSeeded(language: "en")
        choose(app, "export.size.uhd4K", "export.rate.sixty")
        app.terminate()
        app = startApp(seed: nil, drafts: "kept")
        XCTAssertEqual(draftsInfo(app), "1 2+4200+0+2160x60+.")
        app.terminate()

        app = startApp(seed: "two-clips-wide")
        waitForTheEditor(app)
        assertTheLabel(element(app, "editor.exportSettings"), holds: "1080p", "30 fps")
    }

    private func startSeeded(language: String, playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: "two-clips-wide", language: language, playhead: playhead, drafts: "fresh")
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Opens the sheet, taps the size and the rate, each waited for until it reads as selected, then Done, and
    /// waits until the sheet is gone. A sheet that does not come prints the tree.
    private func choose(_ app: XCUIApplication, _ size: String, _ rate: String) {
        element(app, "editor.exportSettings").tap()
        var last = CGRect.zero
        let shown = waitUntil("the sheet standing after the tap on editor.exportSettings", expected: expectedSheet) {
            let done = self.element(app, "export.settingsDone")
            guard done.exists && self.element(app, size).exists else {
                return false
            }
            let now = done.frame
            defer { last = now }
            return now == last
        }
        if !shown {
            print(app.debugDescription)
        }
        element(app, size).tap()
        waitUntil(size + " selected after the tap on it") { self.element(app, size).isSelected }
        element(app, rate).tap()
        waitUntil(rate + " selected after the tap on it") { self.element(app, rate).isSelected }
        element(app, "export.settingsDone").tap()
        let export = element(app, "editor.export")
        waitUntil("the sheet gone and editor.export hittable after the tap on Done") {
            !self.element(app, size).exists && export.exists && export.isHittable
        }
    }

    private func assertTheLabel(_ choice: XCUIElement, holds size: String, _ rate: String) {
        print("export-kept: editor.exportSettings reads " + choice.label)
        XCTAssertTrue(choice.label.contains(size), choice.label)
        XCTAssertTrue(choice.label.contains(rate), choice.label)
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: 10) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("export-kept: start.draftsInfo reads " + label)
        return label
    }

    /// Waits for a button of the panel as ExportChoiceTests does: prints the seconds it took and fails only at three
    /// times the expected value. A question of the system is answered with its last button and named in the log.
    private func waitForTheButton(_ app: XCUIApplication, _ identifier: String, expected: Double) -> XCUIElement {
        let button = element(app, identifier)
        let question = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        let start = Date()
        while !button.waitForExistence(timeout: 1) && Date().timeIntervalSince(start) < expected * 3 {
            if question.exists {
                print("export-kept: the system asked a question during the export: " + question.label)
                question.buttons.element(boundBy: question.buttons.count - 1).tap()
            }
        }
        let took = Date().timeIntervalSince(start)
        print("export-kept: " + identifier + " after " + String(format: "%.1f", took) + " seconds, expected "
            + String(expected) + ", limit " + String(expected * 3))
        XCTAssertTrue(button.exists, identifier + " did not come within " + String(expected * 3) + " seconds")
        return button
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds.
    @discardableResult
    private func waitUntil(_ what: String, expected: Double = 1, _ reached: () -> Bool) -> Bool {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !holds && waited <= first + 3 * expected {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("export-kept: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
