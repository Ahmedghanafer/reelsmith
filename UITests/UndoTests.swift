import XCTest

// Undo and redo in the row of play, on the seeds two-clips-wide (blue 3 seconds, then red 4, on the landscape
// canvas) and text-wide (its text selected at the start, the panel on the part look). The row is fixed left
// to right in every language. Places are compared in whole points with a room of 1 point. That an undo
// reached the player is read from the count of builds, the value of `editor.picture`, and once after it from
// a share of blue in the picture, which a build that failed cannot give. The text is read from the value of
// `text.field` and from field 6 of `editor.textInfo`, its centre as "x,y".
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class UndoTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// At 2 seconds the blue clip fills the wide picture area, so the share of blue is more than this.
    private let blueOfTheClip = 0.9

    /// The seconds from a change to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The row from left to right.
    private let row = ["editor.play", "editor.time", "editor.undo", "editor.redo"]

    func testTheRowHoldsPlayTheTimeUndoAndRedoWithUndoAndRedoDisabled() {
        let app = startUndo(seed: "two-clips-wide")

        assertTheRow(app)
        XCTAssertFalse(element(app, "editor.undo").isEnabled)
        XCTAssertFalse(element(app, "editor.redo").isEnabled)
        assertTheLabels(app, "Undo", "Redo")
        screenshot("undo-01-row")
    }

    /// At 2 seconds, inside blue, the middle of the red block is on the screen and blue stays under the
    /// playhead through the delete, the undo and the redo.
    func testADeleteIsUndoneAndRedoneAndTheRowStandsStill() {
        let app = startUndo(seed: "two-clips-wide", playhead: 1200)
        let undo = element(app, "editor.undo")
        let redo = element(app, "editor.redo")
        let red = element(app, "editor.clip.2")
        let picture = element(app, "editor.picture")
        let before = frames(app)
        waitUntil("a count of builds in editor.picture after the start") { self.builds(picture) != nil }
        let first = builds(picture)
        XCTAssertNotNil(first, "editor.picture has no count of builds")

        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        element(app, "editor.delete").tap()
        waitUntil("one block, undo enabled, redo disabled and a higher count of builds after the delete") {
            !red.exists && undo.isEnabled && !redo.isEnabled && (self.builds(picture) ?? 0) > (first ?? Int.max)
        }
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertFalse(red.exists)
        XCTAssertTrue(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)

        let deleted = builds(picture)
        mark("undo-01-undo")
        undo.tap()
        waitUntil("two blocks, redo enabled, undo disabled and a higher count of builds after the undo") {
            red.exists && redo.isEnabled && !undo.isEnabled && (self.builds(picture) ?? 0) > (deleted ?? Int.max)
        }
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertTrue(red.exists)
        XCTAssertTrue(redo.isEnabled)
        XCTAssertFalse(undo.isEnabled)
        let found = waitForTheShare(of: blue, "blue", in: picture, moreThan: blueOfTheClip)
        print("undo: after the undo the share of blue is \(found), B \(blueOfTheClip)")
        XCTAssertGreaterThan(found, blueOfTheClip, "blue after the undo")
        screenshot("undo-02-undone")

        let undone = builds(picture)
        redo.tap()
        waitUntil("one block and a higher count of builds after the redo") {
            !red.exists && element(app, "editor.clip.1").exists && (self.builds(picture) ?? 0) > (undone ?? Int.max)
        }
        XCTAssertFalse(red.exists)
        // The redo is the last change of the footage, so the share is read once more after it.
        let last = waitForTheShare(of: blue, "blue", in: picture, moreThan: blueOfTheClip)
        print("undo: after the redo the share of blue is \(last), B \(blueOfTheClip)")
        XCTAssertGreaterThan(last, blueOfTheClip, "blue after the redo")

        let after = frames(app)
        for (place, identifier) in row.enumerated() {
            print("undo: \(identifier) at \(before[place]) before the delete and \(after[place]) after the redo")
            XCTAssertEqual(after[place].minX, before[place].minX, accuracy: 1, identifier)
            XCTAssertEqual(after[place].minY, before[place].minY, accuracy: 1, identifier)
            XCTAssertEqual(after[place].width, before[place].width, accuracy: 1, identifier)
            XCTAssertEqual(after[place].height, before[place].height, accuracy: 1, identifier)
        }
    }

    /// The field takes its focus from the tap and the letters from the keyboard. The two letters are one step:
    /// one undo gives the string of the seed back and leaves nothing more to undo.
    func testATypedWordIsUndoneAsOneStepAndRedoneWithThePanelShowing() {
        let app = startUndo(seed: "text-wide")
        let undo = element(app, "editor.undo")
        let redo = element(app, "editor.redo")
        let field = app.textViews["text.field"]
        XCTAssertTrue(element(app, "text.tab.look").isSelected)

        element(app, "text.tab.type").tap()
        waitUntil("the field after the tap on the part type") { field.exists }
        let seed = field.value as? String ?? ""
        print("undo: the field of the seed reads \(seed.count) characters")
        field.tap()
        // A keyboard that does not come fails nothing here: the typing fails by itself with no focus.
        waitUntil("the keyboard after the tap on the field", expected: 2, required: false) {
            app.keyboards.firstMatch.exists
        }
        field.typeText("XY")
        waitUntil("XY in the value of the field and undo enabled after the typing") {
            (field.value as? String ?? "").contains("XY") && undo.isEnabled
        }
        let typed = field.value as? String ?? ""
        XCTAssertNotEqual(typed, seed)

        undo.tap()
        waitUntil("the string of the seed in the field after the undo") { field.value as? String == seed }
        XCTAssertEqual(field.value as? String, seed)
        XCTAssertTrue(element(app, "editor.textRegion").exists)
        XCTAssertTrue(field.exists)
        XCTAssertFalse(undo.isEnabled, "the typed word was more than one step")
        XCTAssertTrue(redo.isEnabled)

        redo.tap()
        waitUntil("the typed value in the field after the redo") { field.value as? String == typed }
        XCTAssertEqual(field.value as? String, typed)
    }

    /// A scripted drag does not promise the distance it moves, so the test asserts a change and its undo,
    /// never a number of pixels.
    func testADragOfTheTextIsUndone() {
        let app = startUndo(seed: "text-wide")
        let picture = element(app, "editor.picture")
        let centre = field(6, app)
        print("undo: field 6 before the drag reads " + centre)

        let start = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 100, dy: 0)))
        waitUntil("a changed field 6 after the drag of 100 points to the right") { self.field(6, app) != centre }
        print("undo: field 6 after the drag reads " + field(6, app))
        XCTAssertNotEqual(field(6, app), centre)

        element(app, "editor.undo").tap()
        waitUntil("field 6 as before the drag after the undo") { self.field(6, app) == centre }
        XCTAssertEqual(field(6, app), centre)
    }

    func testInArabicTheRowIsAsInEnglish() {
        let app = startUndo(seed: "two-clips-wide", language: "ar")

        assertTheRow(app)
        XCTAssertLessThan(element(app, "editor.undo").frame.minX, element(app, "editor.redo").frame.minX)
        assertTheLabels(app, "\u{062A}\u{0631}\u{0627}\u{062C}\u{0639}", "\u{0625}\u{0639}\u{0627}\u{062F}\u{0629}")
        screenshot("undo-01-row-ar")
    }

    func testInSwedish() {
        let app = startUndo(seed: "two-clips-wide", language: "sv")

        assertTheRow(app)
        assertTheLabels(app, "\u{00C5}ngra", "G\u{00F6}r om")
        screenshot("undo-01-row-sv")
    }

    /// The buttons show only their symbols, so their words are read from their labels and printed.
    private func assertTheLabels(_ app: XCUIApplication, _ undo: String, _ redo: String) {
        let undoLabel = element(app, "editor.undo").label
        let redoLabel = element(app, "editor.redo").label
        print("undo: the labels of undo and redo read " + undoLabel + " and " + redoLabel)
        XCTAssertEqual(undoLabel, undo)
        XCTAssertEqual(redoLabel, redo)
    }

    /// Play, the time, undo and redo from left to right under the picture, undo and redo at the trailing end
    /// of the region, each button 44 by 44 points.
    private func assertTheRow(_ app: XCUIApplication) {
        let region = element(app, "editor.previewRegion")
        let picture = region.descendants(matching: .any)["editor.picture"]
        let found = row.map { region.descendants(matching: .any)[$0] }
        for (place, item) in found.enumerated() {
            XCTAssertTrue(item.exists, row[place])
            XCTAssertGreaterThanOrEqual(item.frame.minY, picture.frame.maxY - 1, row[place] + " under the picture")
            if place > 0 {
                XCTAssertGreaterThanOrEqual(
                    item.frame.minX, found[place - 1].frame.maxX - 1, row[place] + " right of " + row[place - 1])
            }
        }
        XCTAssertEqual(found[3].frame.maxX, region.frame.maxX, accuracy: 1, "redo at the trailing end")
        // Undo stands beside redo, the 16 points of the row between them.
        XCTAssertEqual(found[3].frame.minX - found[2].frame.maxX, 16, accuracy: 1, "undo beside redo")
        for place in [0, 2, 3] {
            XCTAssertEqual(found[place].frame.width, 44, accuracy: 1, row[place])
            XCTAssertEqual(found[place].frame.height, 44, accuracy: 1, row[place])
        }
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startUndo(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The frames of the row from left to right.
    private func frames(_ app: XCUIApplication) -> [CGRect] {
        row.map { element(app, $0).frame }
    }

    /// The n-th field of `editor.textInfo`, counted from 1. Empty when the line has no such field.
    private func field(_ place: Int, _ app: XCUIApplication) -> String {
        let fields = app.staticTexts["editor.textInfo"].label.split(separator: " ")
        return fields.count >= place ? String(fields[place - 1]) : ""
    }

    /// The value of `editor.picture` as a number: the count of the items the preview began to build.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    /// No element says when the frame is drawn, so the share is asked again until it is more than wanted.
    /// Prints the seconds it waited, gives up only above three times the expected seconds, and answers the
    /// last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, moreThan wanted: Double
    ) -> Double {
        let started = Date()
        var found = share(of: colour, in: picture)
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !(found > wanted) && waited <= first + 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print("undo: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, for the effect of a tap, a drag or typing. It fails only above three
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
        print("undo: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
