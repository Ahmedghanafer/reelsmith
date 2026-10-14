import XCTest

// The whole path of an export at a chosen size and rate, on the seed two-clips-wide: blue for 3 seconds then red
// for 4 on the landscape canvas. The walk exports at 720p and 60, deletes the red block, exports the 3 seconds of
// blue at 4K and 60, and starts again to the start choice. The choice is read only through the label of
// `editor.exportSettings`, the trait selected in the sheet and `export.fileInfo` on the saved panel. No picture is
// judged by a pixel. Places are compared in whole points with a room of 1 point.
//
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/exists
// https://developer.apple.com/documentation/xctest/xcuielement/ishittable
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholeExportPathTests: XCTestCase {
    /// The export of 7 seconds at 720p and 60 with its save, in seconds. A wait fails at three times this.
    private let expected720 = 30.0

    /// The export of 3 seconds at 4K and 60 with its save in the hosted simulator, in seconds (E14). A wait fails
    /// at three times this.
    private let expected4K = 120.0

    /// The seconds the export trial printed for one second of the blink clip at 3840 by 2160 and 60 with the HEVC
    /// preset on the hosted Mac, in compile check run 38528134806. Printed beside the seconds of the 4K export.
    private let trial4K = 1.46

    /// The start of the walk and of its step, for the printed times.
    private var walkBegan = Date()
    private var stepBegan = Date()

    func testTheWholePathOfAnExportAtAChosenSizeAndRate() {
        mark("export-path-01-path")
        walkBegan = Date()
        stepBegan = walkBegan
        // At 4 seconds the middles of both blocks are on the screen, so the red block can be tapped.
        var app = startPath(playhead: 2400)
        let choice = element(app, "editor.exportSettings")

        // The start choice, then 720p and 60.
        assertTheLabel(choice, holds: "1080p", "30 fps")
        choose(app, "export.size.hd720", "export.rate.sixty")
        assertTheLabel(choice, holds: "720p", "60 fps")
        stepDone("the choice of 720p and 60")

        // The export of 7 seconds at 720p and 60.
        let took720 = export(app, expected: expected720)
        print("export-path: the export of 7 seconds at 720p and 60 took \(took720) seconds")
        XCTAssertEqual(element(app, "export.fileInfo").label, "1280 720 60")
        screenshot("export-path-01-saved-720")
        closeThePanel(app)
        stepDone("the export at 720p and 60")

        // The delete of the red block, so the project is blue alone, 3 seconds.
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("editor.clip.2 selected after the tap on it") { red.isSelected }
        element(app, "editor.delete").tap()
        let time = element(app, "editor.time")
        waitUntil("one block and editor.time ending with 00:03 after the tap on editor.delete") {
            element(app, "editor.clip.1").exists && !red.exists && time.label.hasSuffix("00:03")
        }
        print("export-path: editor.time reads " + time.label)
        stepDone("the delete")

        // 4K and 60 (branch 1).
        choose(app, "export.size.uhd4K", "export.rate.sixty")
        assertTheLabel(choice, holds: "4K", "60 fps")
        screenshot("export-path-02-chosen-4k")
        stepDone("the choice of 4K and 60")

        // E14: the export of 3 seconds at 4K and 60 in the simulator.
        let took4K = export(app, expected: expected4K)
        print(
            "export-path: the export of 3 seconds at 4K and 60 took \(took4K) seconds in the simulator. The export trial took \(trial4K) seconds for one second at 4K and 60 with the HEVC preset on the hosted Mac, compile check run 38528134806"
        )
        XCTAssertEqual(element(app, "export.fileInfo").label, "3840 2160 60")
        screenshot("export-path-03-saved-4k")
        closeThePanel(app)
        stepDone("the export at 4K and 60")

        // The relaunch on the same seed: nothing of the choice is kept.
        app.terminate()
        app = startPath()
        assertTheLabel(element(app, "editor.exportSettings"), holds: "1080p", "30 fps")
        stepDone("the relaunch")
        print("export-path: walk finished, \(Date().timeIntervalSince(walkBegan)) seconds")
    }

    func testInArabicAndSwedishTheChoiceShowsBesideExport() {
        for language in ["ar", "sv"] {
            let app = startPath(language: language)
            choose(app, "export.size.uhd4K", "export.rate.sixty")
            let choice = element(app, "editor.exportSettings").frame
            let export = element(app, "editor.export").frame
            print("export-path: in \(language) editor.exportSettings at \(choice), editor.export at \(export)")
            if language == "ar" {
                XCTAssertGreaterThanOrEqual(choice.minX, export.maxX - 1, "the choice right of Export in ar")
            } else {
                XCTAssertLessThanOrEqual(choice.maxX, export.minX + 1, "the choice left of Export in sv")
            }
            screenshot("export-path-02-chosen-4k-" + language)
        }
    }

    /// Starts the app on two-clips-wide and waits for the editor with the shared helper.
    private func startPath(language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: "two-clips-wide", language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Opens the sheet, taps the size and then the rate, each waited for until it reads as selected, and Done.
    private func choose(_ app: XCUIApplication, _ size: String, _ rate: String) {
        element(app, "editor.exportSettings").tap()
        // The sheet stands when Done is in the same place on two reads in a row.
        var last = CGRect.zero
        waitUntil("the sheet standing after the tap on editor.exportSettings", expected: 10.0 / 3) {
            let done = element(app, "export.settingsDone")
            guard done.exists && element(app, size).exists else {
                return false
            }
            let now = done.frame
            defer { last = now }
            return now == last
        }
        for identifier in [size, rate] {
            element(app, identifier).tap()
            waitUntil(identifier + " selected after the tap on it") { element(app, identifier).isSelected }
        }
        element(app, "export.settingsDone").tap()
        let export = element(app, "editor.export")
        waitUntil("the sheet gone and editor.export hittable after the tap on export.settingsDone") {
            !element(app, size).exists && export.exists && export.isHittable
        }
    }

    private func assertTheLabel(_ choice: XCUIElement, holds size: String, _ rate: String) {
        print("export-path: editor.exportSettings reads " + choice.label)
        XCTAssertTrue(choice.label.contains(size), choice.label)
        XCTAssertTrue(choice.label.contains(rate), choice.label)
    }

    /// Taps Export and waits for the saved panel or the failed one. A failed panel prints its words. Answers the
    /// seconds from the tap to the panel.
    private func export(_ app: XCUIApplication, expected: Double) -> Double {
        let done = element(app, "export.done")
        let close = element(app, "export.close")
        let started = Date()
        element(app, "editor.export").tap()
        waitUntil("the saved panel after the tap on editor.export", expected: expected) { done.exists || close.exists }
        let took = Date().timeIntervalSince(started)
        if close.exists {
            print("export-path: the export failed, export.words reads " + element(app, "export.words").label)
        }
        XCTAssertTrue(done.exists, "the saved panel")
        return took
    }

    /// Taps Done of the saved panel, or Close of the failed one, and waits for the editor.
    private func closeThePanel(_ app: XCUIApplication) {
        let identifier = element(app, "export.done").exists ? "export.done" : "export.close"
        element(app, identifier).tap()
        let export = element(app, "editor.export")
        waitUntil("the panel gone and editor.export hittable after the tap on " + identifier) {
            !element(app, identifier).exists && export.exists && export.isHittable
        }
    }

    /// Prints the seconds of the step that ends here and the seconds since the start of the walk.
    private func stepDone(_ what: String) {
        let now = Date()
        print(
            "export-path: step \(what) took \(now.timeIntervalSince(stepBegan)) seconds, \(now.timeIntervalSince(walkBegan)) since the start of the walk"
        )
        stepBegan = now
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
        print("export-path: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
