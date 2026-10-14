import XCTest

// The choice of size and rate beside Export, on the seed two-clips-wide: blue for 3 seconds then red for 4 on the
// landscape canvas. The choice is read through the label of `editor.exportSettings`, the trait selected in the
// sheet and `export.fileInfo` on the saved panel. Places are compared in whole points with a room of 1 point.
// The class sorts before ExportPanelTests, so its export is the first of its run and is expected to be slow.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementquery/allelementsboundbyindex
// https://developer.apple.com/documentation/xctest/xcuiapplication/init(bundleidentifier:)
@MainActor
final class ExportChoiceTests: XCTestCase {
    /// The export of 7 seconds at 720p and 60 with its save, the first export of its run, in seconds.
    private let expectedSaved = 45.0
    /// The story fails the sheet at 10 seconds after the tap, three times this.
    private let expectedSheet = 10.0 / 3

    private let sizes = ["export.size.hd720", "export.size.hd1080", "export.size.uhd4K"]
    private let rates = ["export.rate.thirty", "export.rate.sixty"]

    func testTheChoiceIsHeldInTheSheetAndTheLabelAndTheFileHasIt() {
        let app = startChoice()
        let region = element(app, "editor.exportRegion")
        let choice = element(app, "editor.exportSettings")
        let export = element(app, "editor.export")

        // Criterion 1: two buttons in the region, both enabled, the choice left of Export.
        XCTAssertEqual(region.buttons.allElementsBoundByIndex.map { $0.identifier }, ["editor.exportSettings", "editor.export"])
        XCTAssertTrue(choice.isEnabled)
        XCTAssertTrue(export.isEnabled)
        XCTAssertLessThanOrEqual(choice.frame.maxX, export.frame.minX + 1)
        assertTheLabel(choice, holds: "1080p", "30 fps")
        let exportBefore = export.frame

        openTheSheet(app)
        for identifier in sizes + rates + ["export.settingsDone"] {
            XCTAssertTrue(element(app, identifier).exists, identifier)
        }
        assertSelected(app, ["export.size.hd1080", "export.rate.thirty"])
        screenshot("export-choice-01-sheet")

        // Criterion 2: the trait moves with each tap and no button of the sheet moves.
        let places = (sizes + rates + ["export.settingsDone"]).map { element(app, $0).frame }
        assertOneWidth(app, sizes)
        assertOneWidth(app, rates)
        element(app, "export.size.hd720").tap()
        waitUntil("export.size.hd720 selected after the tap on it") {
            element(app, "export.size.hd720").isSelected && !element(app, "export.size.hd1080").isSelected
        }
        element(app, "export.rate.sixty").tap()
        waitUntil("export.rate.sixty selected after the tap on it") {
            element(app, "export.rate.sixty").isSelected && !element(app, "export.rate.thirty").isSelected
        }
        assertSelected(app, ["export.size.hd720", "export.rate.sixty"])
        for (identifier, before) in zip(sizes + rates + ["export.settingsDone"], places) {
            assertSamePlace(element(app, identifier).frame, before, identifier)
        }

        // Criterion 3: Done takes the sheet away, the label follows and Export stands where it stood.
        element(app, "export.settingsDone").tap()
        waitUntil("the sheet gone and editor.export hittable after the tap on Done") {
            !element(app, "export.size.hd720").exists && export.exists && export.isHittable
        }
        assertTheLabel(choice, holds: "720p", "60 fps")
        assertSamePlace(export.frame, exportBefore, "editor.export")
        screenshot("export-choice-02-chosen")
        openTheSheet(app)
        assertSelected(app, ["export.size.hd720", "export.rate.sixty"])
        element(app, "export.settingsDone").tap()
        waitUntil("the sheet gone and editor.export hittable after the second tap on Done") {
            !element(app, "export.size.hd720").exists && export.exists && export.isHittable
        }

        // Criterion 4: the export writes what was chosen.
        mark("export-choice-01-export")
        export.tap()
        _ = waitForTheButton(app, "export.done", expected: expectedSaved)
        XCTAssertEqual(element(app, "export.fileInfo").label, "1280 720 60")
        screenshot("export-choice-03-saved")

        // Criterion 5: after Done the choice and the project are as they were.
        element(app, "export.done").tap()
        waitUntil("editor.export hittable after the tap on export.done") { export.exists && export.isHittable }
        assertTheLabel(choice, holds: "720p", "60 fps")
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        XCTAssertFalse(element(app, "editor.clip.3").exists)
    }

    func testInArabicTheRowAndTheSheetMirror() {
        let app = startChoice(language: "ar")

        XCTAssertGreaterThanOrEqual(
            element(app, "editor.exportSettings").frame.minX, element(app, "editor.export").frame.maxX - 1)
        openTheSheet(app)
        XCTAssertGreaterThanOrEqual(
            element(app, "export.size.hd720").frame.minX, element(app, "export.size.uhd4K").frame.maxX - 1)
        assertSelected(app, ["export.size.hd1080", "export.rate.thirty"])
        screenshot("export-choice-01-sheet-ar")
    }

    func testInSwedishTheRowAndTheSheetAreAsInEnglish() {
        let app = startChoice(language: "sv")

        XCTAssertLessThanOrEqual(
            element(app, "editor.exportSettings").frame.maxX, element(app, "editor.export").frame.minX + 1)
        openTheSheet(app)
        XCTAssertLessThanOrEqual(
            element(app, "export.size.hd720").frame.maxX, element(app, "export.size.uhd4K").frame.minX + 1)
        assertSelected(app, ["export.size.hd1080", "export.rate.thirty"])
        screenshot("export-choice-01-sheet-sv")
    }

    private func startChoice(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "two-clips-wide", language: language)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Taps the choice and waits for the sheet to stand still: Done in the same place on two reads in a row.
    /// A sheet that does not come prints the tree and fails.
    private func openTheSheet(_ app: XCUIApplication) {
        element(app, "editor.exportSettings").tap()
        var last = CGRect.zero
        let shown = waitUntil("the sheet standing after the tap on editor.exportSettings", expected: expectedSheet) {
            let done = element(app, "export.settingsDone")
            guard done.exists && element(app, "export.size.hd720").exists else {
                return false
            }
            let now = done.frame
            defer { last = now }
            return now == last
        }
        if !shown {
            print(app.debugDescription)
        }
    }

    /// The two named choices are selected and every other choice is not.
    private func assertSelected(_ app: XCUIApplication, _ chosen: [String]) {
        for identifier in sizes + rates {
            XCTAssertEqual(element(app, identifier).isSelected, chosen.contains(identifier), identifier)
        }
    }

    private func assertTheLabel(_ choice: XCUIElement, holds size: String, _ rate: String) {
        print("export-choice: editor.exportSettings reads " + choice.label)
        XCTAssertTrue(choice.label.contains(size), choice.label)
        XCTAssertTrue(choice.label.contains(rate), choice.label)
    }

    private func assertOneWidth(_ app: XCUIApplication, _ row: [String]) {
        let widths = row.map { element(app, $0).frame.width }
        print("export-choice: the widths of " + row.joined(separator: " ") + " are " + widths.map { String(format: "%.1f", $0) }.joined(separator: " "))
        XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), 1, row.joined(separator: " "))
    }

    private func assertSamePlace(_ now: CGRect, _ before: CGRect, _ identifier: String) {
        let moved = max(
            abs(now.minX - before.minX), abs(now.minY - before.minY), abs(now.width - before.width),
            abs(now.height - before.height))
        XCTAssertLessThanOrEqual(moved, 1, identifier + " moved from \(before) to \(now)")
    }

    /// Waits for a button of the panel as ExportPanelTests does: prints the seconds it took and fails only at three
    /// times the expected value. A question of the system is answered with its last button and named in the log.
    private func waitForTheButton(_ app: XCUIApplication, _ identifier: String, expected: Double) -> XCUIElement {
        let button = element(app, identifier)
        let question = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        let start = Date()
        while !button.waitForExistence(timeout: 1) && Date().timeIntervalSince(start) < expected * 3 {
            if question.exists {
                print("export-choice: the system asked a question during the export: " + question.label)
                question.buttons.element(boundBy: question.buttons.count - 1).tap()
            }
        }
        let took = Date().timeIntervalSince(start)
        print("export-choice: " + identifier + " after " + String(format: "%.1f", took) + " seconds, expected "
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
        print("export-choice: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
