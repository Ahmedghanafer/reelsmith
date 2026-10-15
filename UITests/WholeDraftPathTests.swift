import XCTest

// The whole path of a draft in one test: a new project from the system picker (blue 3 seconds, then red 4, on the
// landscape canvas), the red clip deleted, undo, redo, a text "Hi", the export choice of 720p at 60, back to the
// list, a relaunch, the draft opened again with its history and its choice, an undo, an export and a delete.
// Drafts are read through the line `start.draftsInfo`, the editor through `editor.seedInfo` and `editor.textInfo`,
// the choice through the label of `editor.exportSettings` and `export.fileInfo` on the saved panel. No picture is
// judged by a pixel. When the picker is not driven the walk goes on from the seed two-clips-wide, which is the
// same two clips.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/swipeleft()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholeDraftPathTests: XCTestCase {
    /// The seconds from the tap on `editor.projects` to the start screen, the cover written on the way.
    private let expectedBack = 5.0

    /// The export of 3 seconds at 720p and 60 with its save, in seconds, as the first export of a run is.
    private let expectedExport = 45.0

    /// The seconds from a launch to the start screen, the first launch of a fresh simulator included.
    private let expectedStart = 20.0

    /// The draft after the walk: one clip of 1800 ticks, one text, 720p at 60, a cover.
    private let walked = "1 1+1800+1+720x60+c"

    /// The start of the walk and of its step, for the printed times.
    private var walkBegan = Date()
    private var stepBegan = Date()

    func testTheWholePathOfADraftFromANewProjectToADelete() {
        mark("draft-path-01-path")
        walkBegan = Date()
        stepBegan = walkBegan

        // A new project from the picker, on a folder of drafts emptied by the launch.
        var app = startApp(seed: nil, drafts: "fresh")
        XCTAssertEqual(draftsInfo(app), "0")
        let stopped = drivePicker(app)
        if let stopped {
            print("draft-path: picker not driven: \(stopped). The walk goes on from -drafts kept -seed two-clips-wide")
            app.terminate()
            app = startApp(seed: "two-clips-wide", drafts: "kept")
        } else {
            print("draft-path: picker driven")
        }
        waitForTheEditor(app)
        waitUntil("2 clips, 2 files in editor.seedInfo") {
            app.staticTexts["editor.seedInfo"].label == "2 clips, 2 files"
        }
        stepDone("the new project")

        // The red clip deleted, then undo and redo. The strip is dragged so that red is on the screen.
        let red = element(app, "editor.clip.2")
        let region = element(app, "editor.timelineRegion")
        let start = region.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -320, dy: 0)))
        waitUntil("a quarter of the red block on the screen after the drag") {
            let quarter = red.frame.minX + red.frame.width / 4
            return quarter > region.frame.minX + 24 && quarter < region.frame.maxX - 24
        }
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        element(app, "editor.delete").tap()
        waitUntil("one block after the tap on editor.delete") { !red.exists && self.element(app, "editor.clip.1").exists }
        element(app, "editor.undo").tap()
        waitUntil("two blocks after the tap on editor.undo") { red.exists }
        element(app, "editor.redo").tap()
        waitUntil("one block after the tap on editor.redo") { !red.exists && self.element(app, "editor.clip.1").exists }
        stepDone("the delete, the undo and the redo")

        // A text "Hi", ended by Done.
        element(app, "editor.addText").tap()
        let field = app.textViews["text.field"]
        waitUntil("the field after the tap on editor.addText") { field.exists }
        field.tap()
        waitUntil("the keyboard after the tap on the field", expected: 2) { app.keyboards.firstMatch.exists }
        field.typeText("Hi")
        waitUntil("Hi in the value of the field") { field.value as? String == "Hi" }
        element(app, "text.done").tap()
        waitUntil("no text panel after the tap on text.done") { !self.element(app, "editor.textRegion").exists }
        stepDone("the text")

        // The choice of 720p at 60, then back to the list.
        choose(app, "export.size.hd720", "export.rate.sixty")
        assertTheLabel(app, holds: "720p", "60 fps")
        back(app)
        XCTAssertEqual(draftsInfo(app), walked)
        XCTAssertTrue(element(app, "drafts.row.1").exists)
        screenshot("draft-path-01-list")
        stepDone("the choice and back")

        // The app ended. The list in Arabic and in Swedish, each from a launch of its own.
        app.terminate()
        for language in ["ar", "sv"] {
            app = startApp(seed: nil, language: language, drafts: "kept")
            XCTAssertEqual(draftsInfo(app), walked)
            XCTAssertTrue(element(app, "drafts.row.1").exists)
            screenshot("draft-path-01-list-" + language)
            app.terminate()
        }
        stepDone("the list in Arabic and in Swedish")

        // The draft opened again: one clip, its text, its choice, and its history.
        app = startApp(seed: nil, drafts: "kept")
        XCTAssertEqual(draftsInfo(app), walked)
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        waitUntil("1 clips, 1 files in editor.seedInfo") {
            app.staticTexts["editor.seedInfo"].label == "1 clips, 1 files"
        }
        let bar = element(app, "editor.text.1")
        waitUntil("the text bar of the reopened draft") { bar.exists }
        bar.tap()
        waitUntil("text 1 in editor.textInfo after the tap on its bar") {
            app.staticTexts["editor.textInfo"].label.hasPrefix("1 ")
        }
        assertTheLabel(app, holds: "720p", "60 fps")
        let undo = element(app, "editor.undo")
        XCTAssertTrue(undo.isEnabled, "the history did not come back with the draft")
        screenshot("draft-path-02-reopened")
        // The last edit before the relaunch was the text, so the undo takes it away and leaves the one clip.
        undo.tap()
        waitUntil("no text in editor.textInfo after the tap on editor.undo") {
            app.staticTexts["editor.textInfo"].label == "none" && !bar.exists
        }
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertFalse(element(app, "editor.clip.2").exists)
        stepDone("the reopen and the undo")

        // The export at the kept choice.
        let done = element(app, "export.done")
        let close = element(app, "export.close")
        let began = Date()
        element(app, "editor.export").tap()
        waitUntil("the saved panel after the tap on editor.export", expected: expectedExport) {
            done.exists || close.exists
        }
        print("draft-path: the export of 3 seconds at 720p and 60 took \(Date().timeIntervalSince(began)) seconds")
        if close.exists {
            print("draft-path: the export failed, export.words reads " + element(app, "export.words").label)
        }
        XCTAssertTrue(done.exists, "the saved panel")
        XCTAssertEqual(element(app, "export.fileInfo").label, "1280 720 60")
        screenshot("draft-path-03-saved")
        stepDone("the export")

        // Done, back, and the draft deleted with its confirm.
        let panel = done.exists ? "export.done" : "export.close"
        element(app, panel).tap()
        waitUntil("the panel gone after the tap on " + panel) { !self.element(app, panel).exists }
        back(app)
        // A swipe sent while the start screen still settles after the editor closed is lost, so the row is
        // swiped once it stands in the same place on two reads in a row.
        let row = element(app, "drafts.row.1")
        var last = CGRect.zero
        waitUntil("drafts.row.1 standing on the start screen") {
            guard row.exists else {
                return false
            }
            let now = row.frame
            defer { last = now }
            return now == last
        }
        print("draft-path: drafts.row.1 at \(row.frame), start.draftsInfo reads " + draftsInfo(app))
        row.swipeLeft()
        let delete = element(app, "drafts.delete")
        waitUntil("drafts.delete after the swipe on drafts.row.1", expected: 10.0 / 3) { delete.exists }
        delete.tap()
        // The answer of the alert shows as a button inside a button with one identifier, so the first is taken.
        let confirm = app.alerts.buttons["drafts.deleteConfirm"].firstMatch
        waitUntil("drafts.deleteConfirm after the tap on drafts.delete", expected: 2) { confirm.exists }
        confirm.tap()
        waitUntil("no row after the tap on drafts.deleteConfirm", expected: 2) {
            !self.element(app, "drafts.row.1").exists
        }
        XCTAssertEqual(draftsInfo(app), "0")
        stepDone("the delete")

        // A run in which this line is missing did not walk, whatever its result says.
        let seconds = Int(Date().timeIntervalSince(walkBegan))
        let picker = stopped == nil ? "picker driven" : "picker not driven, from the seed two-clips-wide"
        print("draft-path: walk finished, \(picker), \(seconds) seconds")
    }

    /// Taps `start.newProject`, then the shared driver of the picker chooses blue then red and confirms. Nil when the
    /// editor opened, else the step that found nothing.
    private func drivePicker(_ app: XCUIApplication) -> String? {
        element(app, "start.newProject").tap()
        if let stopped = chooseInThePhotoPicker(app, fromTheEnd: [1, 2], confirms: true, picture: nil, photos: true) {
            return stopped
        }
        let began = Date()
        let opened = element(app, "editor.root").waitForExistence(timeout: 3 * expectedStart)
        print("draft-path: waited \(Date().timeIntervalSince(began)) seconds for editor.root after the picker, expected \(expectedStart), limit \(3 * expectedStart)")
        return opened ? nil : "the editor did not open within \(3 * expectedStart) seconds of the tap on the right of the picker's bar"
    }

    /// The tap on `editor.projects` and the wait for the start screen, printed.
    private func back(_ app: XCUIApplication) {
        element(app, "editor.projects").tap()
        waitUntil("start.newProject after the tap on editor.projects", expected: expectedBack) {
            self.element(app, "start.newProject").exists
        }
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: expectedStart) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("draft-path: start.draftsInfo reads " + label)
        return label
    }

    /// Opens the sheet, taps the size and then the rate, each waited for until it reads as selected, and Done.
    private func choose(_ app: XCUIApplication, _ size: String, _ rate: String) {
        element(app, "editor.exportSettings").tap()
        // The sheet stands when Done is in the same place on two reads in a row.
        var last = CGRect.zero
        waitUntil("the sheet standing after the tap on editor.exportSettings", expected: 10.0 / 3) {
            let done = self.element(app, "export.settingsDone")
            guard done.exists && self.element(app, size).exists else {
                return false
            }
            let now = done.frame
            defer { last = now }
            return now == last
        }
        for identifier in [size, rate] {
            element(app, identifier).tap()
            waitUntil(identifier + " selected after the tap on it") { self.element(app, identifier).isSelected }
        }
        element(app, "export.settingsDone").tap()
        let export = element(app, "editor.export")
        waitUntil("the sheet gone and editor.export hittable after the tap on export.settingsDone") {
            !self.element(app, size).exists && export.exists && export.isHittable
        }
    }

    private func assertTheLabel(_ app: XCUIApplication, holds size: String, _ rate: String) {
        let label = element(app, "editor.exportSettings").label
        print("draft-path: editor.exportSettings reads " + label)
        XCTAssertTrue(label.contains(size), label)
        XCTAssertTrue(label.contains(rate), label)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Prints the seconds of the step that ends here and the seconds since the start of the walk.
    private func stepDone(_ what: String) {
        let now = Date()
        print(
            "draft-path: step \(what) took \(now.timeIntervalSince(stepBegan)) seconds, \(now.timeIntervalSince(walkBegan)) since the start of the walk"
        )
        stepBegan = now
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds.
    private func waitUntil(_ what: String, expected: Double = 1, _ reached: () -> Bool) {
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
        print("draft-path: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
