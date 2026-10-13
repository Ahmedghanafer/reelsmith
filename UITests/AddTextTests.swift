import XCTest

// The text button, the text region and the text panel, on the seeds two-clips-wide (blue 3 seconds, red 4,
// the landscape canvas, no text), text-wide, text-box-wide and empty. The values of the selected text are
// read from `editor.textInfo`, whose first field is the position of the text, and its string as the value
// of `text.field`. The preview does not follow a text edit yet, so no test here reads the picture.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielement/ishittable
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/keyboards
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/textviews
@MainActor
final class AddTextTests: XCTestCase {
    func testTheTextButtonStandsAfterDeleteAndASeededStartShowsItsTwoLines() {
        let app = startText(seed: "two-clips-wide")
        let add = element(app, "editor.toolsRegion").descendants(matching: .any)["editor.addText"]

        XCTAssertTrue(add.exists)
        XCTAssertEqual(add.label, "Text")
        XCTAssertTrue(add.isEnabled)
        // After Delete, which is the trailing side.
        XCTAssertGreaterThan(add.frame.minX, element(app, "editor.delete").frame.minX)

        // Nothing is selected on this seed, and the two faces are the ones the font files name.
        let seedInfo = app.staticTexts["editor.seedInfo"]
        let textInfo = app.staticTexts["editor.textInfo"]
        let faceInfo = app.staticTexts["editor.faceInfo"]
        XCTAssertEqual(textInfo.label, "none")
        XCTAssertEqual(faceInfo.label, "Amiri-Regular Amiri-Bold")
        XCTAssertLessThan(seedInfo.frame.minY, textInfo.frame.minY)
        XCTAssertLessThan(textInfo.frame.minY, faceInfo.frame.minY)
        XCTAssertFalse(element(app, "editor.textRegion").exists)
        screenshot("add-text-01-button")
    }

    func testOnAnEmptyProjectTheTextButtonIsThereAndNotEnabled() {
        let app = startText(seed: "empty")
        let add = element(app, "editor.addText")

        XCTAssertTrue(add.exists)
        XCTAssertFalse(add.isEnabled)
    }

    func testWithNoSeedNeitherLineOfASeededStartShows() {
        let app = startApp(seed: nil)

        XCTAssertTrue(element(app, "start.newProject").waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["editor.textInfo"].exists)
        XCTAssertFalse(app.staticTexts["editor.faceInfo"].exists)
    }

    func testAddingATextShowsThePanelAndTheTypedLinesAreKept() {
        let app = startText(seed: "two-clips-wide")
        addAText(app)

        // The region lies between the tools and the export and holds the controls of the panel.
        let region = element(app, "editor.textRegion")
        XCTAssertGreaterThanOrEqual(region.frame.minY, element(app, "editor.toolsRegion").frame.maxY - 1)
        XCTAssertLessThanOrEqual(region.frame.maxY, element(app, "editor.exportRegion").frame.minY + 1)
        XCTAssertEqual(textInfo(app), "1 naskh 64 255,255,255 centre 960,540 0 ... 0+4200 0")
        let typeTab = region.descendants(matching: .any)["text.tab.type"]
        let lookTab = region.descendants(matching: .any)["text.tab.look"]
        let moreTab = region.descendants(matching: .any)["text.tab.more"]
        let done = region.descendants(matching: .any)["text.done"]
        let field = region.textViews["text.field"]
        for control in [typeTab, lookTab, moreTab, done, field] {
            XCTAssertTrue(control.exists)
        }
        guard typeTab.exists, lookTab.exists, moreTab.exists, done.exists, field.exists else {
            return
        }
        // One row from leading to trailing, with done at its trailing end.
        XCTAssertLessThan(typeTab.frame.minX, lookTab.frame.minX)
        XCTAssertLessThan(lookTab.frame.minX, moreTab.frame.minX)
        XCTAssertGreaterThan(done.frame.minX, moreTab.frame.maxX)
        XCTAssertEqual(Double(done.frame.midY), Double(typeTab.frame.midY), accuracy: 4)
        // The text is blank, so the part type shows, with the field under the row.
        XCTAssertTrue(typeTab.isSelected)
        XCTAssertFalse(lookTab.isSelected)
        XCTAssertGreaterThanOrEqual(field.frame.minY, typeTab.frame.maxY - 1)
        screenshot("add-text-04-panel")

        field.tap()
        waitUntil("the keyboard after the tap on the field", expected: 2) { app.keyboards.firstMatch.exists }
        XCTAssertTrue(field.isHittable)
        XCTAssertTrue(done.isHittable)
        screenshot("add-text-02-keyboard")

        field.typeText("Peace\nbe upon you")
        waitUntil("both typed lines as the value of the field") { field.value as? String == "Peace\nbe upon you" }
        XCTAssertEqual(position(app), "1")

        // Done hides the panel and keeps the text: the next one is the second.
        tapDone(app)
        waitUntil("no selected text after done") { textInfo(app) == "none" }
        addAText(app)
        waitUntil("the position 2 for the next text") { position(app) == "2" }
    }

    func testDoneIsSeenFromEveryPart() {
        let app = startText(seed: "two-clips-wide")
        addAText(app)
        let done = element(app, "text.done")

        for part in ["text.tab.look", "text.tab.more"] {
            let button = element(app, part)
            button.tap()
            waitUntil(part + " selected after the tap on it") { button.isSelected }
            XCTAssertFalse(element(app, "text.tab.type").isSelected)
            XCTAssertFalse(app.textViews["text.field"].exists)
            XCTAssertTrue(done.exists)
            XCTAssertTrue(done.isHittable)
        }
    }

    func testABlankTextIsGoneAfterDone() {
        let app = startText(seed: "two-clips-wide")

        // Nothing typed: the text is gone, so the next one is the first again.
        addAText(app)
        waitUntil("the position 1 for the first text") { position(app) == "1" }
        tapDone(app)
        addAText(app)
        waitUntil("the position 1 after a text with nothing typed") { position(app) == "1" }

        // Only spaces typed: the same.
        let field = app.textViews["text.field"]
        typeInTheField(app, "  ")
        waitUntil("only spaces as the value of the field") {
            let value = field.value as? String ?? ""
            return !value.isEmpty && value.allSatisfy { $0 == " " }
        }
        tapDone(app)
        addAText(app)
        waitUntil("the position 1 after a text of spaces") { position(app) == "1" }
    }

    func testDeleteRemovesASelectedTextAndLeavesBothClips() {
        let app = startText(seed: "two-clips-wide")
        addAText(app)
        let field = app.textViews["text.field"]
        typeInTheField(app, "Peace")
        waitUntil("the typed word as the value of the field") { field.value as? String == "Peace" }

        let delete = element(app, "editor.delete")
        XCTAssertTrue(delete.isEnabled)
        delete.tap()
        waitUntil("the text region gone after the tap on delete") { !element(app, "editor.textRegion").exists }
        XCTAssertEqual(textInfo(app), "none")
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        let time = element(app, "editor.time").label
        XCTAssertTrue(time.hasSuffix("00:07"), time)

        // The typed text is gone, so the next one is the first again.
        addAText(app)
        waitUntil("the position 1 after the delete") { position(app) == "1" }
    }

    func testATextAndAClipAreNeverSelectedTogether() {
        // At 4 seconds the middles of both blocks are on the screen.
        let app = startText(seed: "two-clips-wide", playhead: 2400)
        let start = element(app, "editor.trim.start")
        let end = element(app, "editor.trim.end")

        element(app, "editor.clip.2").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("both trim handles after the tap on the second block") { start.exists && end.exists }

        addAText(app)
        waitUntil("both trim handles gone after the tap on the text button") { !start.exists && !end.exists }
        XCTAssertFalse(element(app, "editor.clip.2").isSelected)

        element(app, "editor.clip.1").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the text region gone after the tap on the first block") {
            !element(app, "editor.textRegion").exists
        }
    }

    func testAStartOnATextSeedHasItsTextSelectedAndThePanelOnThePartLook() {
        var app = startText(seed: "text-wide")
        XCTAssertTrue(element(app, "editor.textRegion").exists)
        XCTAssertEqual(textInfo(app), "1 naskh 64 255,255,255 centre 960,540 0 ... 0+4200 0")
        // The text has a string, so the part look shows.
        XCTAssertTrue(element(app, "text.tab.look").isSelected)
        let field = app.textViews["text.field"]
        XCTAssertFalse(field.exists)

        element(app, "text.tab.type").tap()
        waitUntil("the field after the tap on the part type") { field.exists }
        // The middle line of the seed, as scalars so no editor reorders it.
        let arabic =
            "\u{0627}\u{0644}\u{0633}\u{0651}\u{064E}\u{0644}\u{064E}\u{0627}\u{0645}\u{064F}\u{0020}"
            + "\u{0639}\u{064E}\u{0644}\u{064E}\u{064A}\u{0652}\u{0643}\u{064F}\u{0645}\u{0652}"
        XCTAssertEqual(field.value as? String, "Peace\n" + arabic + "\nbe upon you")
        screenshot("add-text-03-arabic-field")

        app = startText(seed: "text-box-wide")
        XCTAssertTrue(element(app, "editor.textRegion").exists)
        XCTAssertEqual(textInfo(app), "1 naskh 96 255,214,10 centre 960,540 0 ..b 600+900 0")
        XCTAssertTrue(element(app, "text.tab.look").isSelected)
    }

    func testInArabicTheToolsRowAndThePanelMirror() {
        let app = startText(seed: "two-clips-wide", language: "ar")
        addAText(app)
        let add = element(app, "editor.addText")
        let done = element(app, "text.done")

        // The Arabic lines of the word file.
        XCTAssertEqual(add.label, "نص")
        XCTAssertEqual(done.label, "تم")
        // Leading is the right now: the text button is left of Delete, and done is at the left end of its row.
        XCTAssertLessThan(add.frame.minX, element(app, "editor.delete").frame.minX)
        XCTAssertGreaterThan(element(app, "text.tab.type").frame.minX, element(app, "text.tab.look").frame.minX)
        XCTAssertGreaterThan(element(app, "text.tab.look").frame.minX, element(app, "text.tab.more").frame.minX)
        XCTAssertLessThan(done.frame.maxX, element(app, "text.tab.more").frame.minX)
        // The preview and the strip do not mirror.
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertLessThan(element(app, "editor.clip.1").frame.minX, element(app, "editor.clip.2").frame.minX)
        screenshot("add-text-04-panel-ar")
    }

    func testInSwedishThePanelShowsItsSwedishWords() {
        let app = startText(seed: "two-clips-wide", language: "sv")
        addAText(app)

        XCTAssertEqual(element(app, "editor.addText").label, "Text")
        XCTAssertEqual(element(app, "text.tab.type").label, "Skriv")
        XCTAssertEqual(element(app, "text.tab.look").label, "Utseende")
        XCTAssertEqual(element(app, "text.tab.more").label, "Mer")
        XCTAssertEqual(element(app, "text.done").label, "Klar")
        XCTAssertGreaterThan(element(app, "text.done").frame.minX, element(app, "text.tab.more").frame.maxX)
        screenshot("add-text-04-panel-sv")
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startText(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func textInfo(_ app: XCUIApplication) -> String {
        app.staticTexts["editor.textInfo"].label
    }

    /// The first field of `editor.textInfo`: the position of the selected text, or "none".
    private func position(_ app: XCUIApplication) -> String {
        String(textInfo(app).split(separator: " ").first ?? "")
    }

    /// Taps the text button and waits for the text region.
    private func addAText(_ app: XCUIApplication) {
        element(app, "editor.addText").tap()
        waitUntil("the text region after the tap on the text button") { element(app, "editor.textRegion").exists }
    }

    /// Taps done and waits until the text region is gone.
    private func tapDone(_ app: XCUIApplication) {
        element(app, "text.done").tap()
        waitUntil("the text region gone after the tap on done") { !element(app, "editor.textRegion").exists }
    }

    /// Taps the field, waits for the keyboard and types. A keyboard that does not come is printed and
    /// fails nothing here: the typing fails by itself when the field has no focus.
    private func typeInTheField(_ app: XCUIApplication, _ string: String) {
        let field = app.textViews["text.field"]
        field.tap()
        waitUntil("the keyboard after the tap on the field", expected: 2, required: false) {
            app.keyboards.firstMatch.exists
        }
        field.typeText(string)
    }

    /// Reads until the condition holds, for the effect of a tap or of typing. It fails only above three
    /// times the expected seconds: a hosted runner under load can hold the app for seconds.
    @discardableResult
    private func waitUntil(
        _ what: String, expected: Double = 1, required: Bool = true, _ reached: () -> Bool
    ) -> Bool {
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
        print("add-text: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
