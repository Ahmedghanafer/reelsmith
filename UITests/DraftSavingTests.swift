import XCTest

// Saving a draft, read only through the line `start.draftsInfo` of the start screen after a launch with
// `-drafts kept` and no seed. Each test starts its first launch with `-drafts fresh`, which empties the test
// folder of drafts. The seed two-clips-wide is blue 3 seconds, then red 4, on the landscape canvas, so its
// draft reads "2+4200+0+1080x30+." and with the red clip deleted "1+1800+0+1080x30+.".
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuidevice/press(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class DraftSavingTests: XCTestCase {
    func testWithNoDraftTheLineReadsZero() {
        let app = startApp(seed: nil, drafts: "fresh")

        XCTAssertEqual(draftsInfo(app), "0")
        screenshot("draft-saving-01-start")
    }

    func testInArabic() {
        let app = startApp(seed: nil, language: "ar", drafts: "fresh")

        XCTAssertEqual(draftsInfo(app), "0")
        screenshot("draft-saving-01-start-ar")
    }

    func testInSwedish() {
        let app = startApp(seed: nil, language: "sv", drafts: "fresh")

        XCTAssertEqual(draftsInfo(app), "0")
        screenshot("draft-saving-01-start-sv")
    }

    func testADeleteIsKeptAcrossALaunch() {
        let app = startSeeded(drafts: "fresh")
        // The two files were copied into the draft's media folder, which the line counts.
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "2 clips, 2 files")

        deleteRed(app)
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 1+1800+0+1080x30+.")
    }

    /// The typed word is a run, which is not written while it is open, so only the leave of the active phase
    /// writes it.
    func testATypedWordIsWrittenWhenTheAppLeaves() {
        let app = startSeeded(drafts: "fresh")
        typeHi(app)

        XCUIDevice.shared.press(.home)
        print("draft-saving: the home button pressed, 2 seconds given to the app as the story says")
        Thread.sleep(forTimeInterval: 2)
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 2+4200+1+1080x30+.")
    }

    func testAnUndoIsWritten() {
        let app = startSeeded(drafts: "fresh")
        deleteRed(app)
        element(app, "editor.undo").tap()
        waitUntil("two blocks after the undo") { self.element(app, "editor.clip.2").exists }
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 2+4200+0+1080x30+.")
    }

    func testASeededStartWithoutDraftsWritesNothing() {
        var app = startApp(seed: nil, drafts: "fresh")
        XCTAssertEqual(draftsInfo(app), "0")
        app.terminate()

        app = startApp(seed: "two-clips-wide", playhead: 1200)
        waitForTheEditor(app)
        deleteRed(app)
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "0")
    }

    /// The typed word is a run, which only Save writes before the app is ended.
    func testSaveWritesTheEdit() {
        let app = startSeeded(drafts: "fresh")
        typeHi(app)

        element(app, "editor.save").tap()
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 2+4200+1+1080x30+.")
    }

    /// The control of the test above: with the run of the typed word open and no home button, ending the app
    /// writes nothing, so the draft is still the seed's, with no text.
    func testEndingTheAppWithATypedRunOpenWritesNothing() {
        let app = startSeeded(drafts: "fresh")
        typeHi(app)

        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 2+4200+0+1080x30+.")
    }

    /// Starts on two-clips-wide at 2 seconds, so the red block is on the screen, and waits for the editor: the
    /// first seeded start in a fresh simulator writes the clips first.
    private func startSeeded(drafts: String) -> XCUIApplication {
        let app = startApp(seed: "two-clips-wide", playhead: 1200, drafts: drafts)
        waitForTheEditor(app)
        return app
    }

    /// Selects the red block and deletes it. At 2 seconds, inside blue, the first quarter of red is on the screen.
    private func deleteRed(_ app: XCUIApplication) {
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        element(app, "editor.delete").tap()
        waitUntil("one block after the delete") { !red.exists }
    }

    /// Adds a text and types "Hi" into its field.
    private func typeHi(_ app: XCUIApplication) {
        element(app, "editor.addText").tap()
        let field = app.textViews["text.field"]
        waitUntil("the field after the tap on Text") { field.exists }
        field.tap()
        waitUntil("the keyboard after the tap on the field", expected: 2) { app.keyboards.firstMatch.exists }
        field.typeText("Hi")
        waitUntil("Hi in the value of the field") { field.value as? String == "Hi" }
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: 10) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("draft-saving: start.draftsInfo reads " + label)
        return label
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads until the condition holds, for the effect of a launch, a tap or typing. It fails only above three
    /// times the expected seconds: a hosted runner under load can hold the app for seconds.
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
        print("draft-saving: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
