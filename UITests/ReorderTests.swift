import XCTest

// Moving a clip with a press and drag of its block. On `three-clips` blue is 3 seconds, red 4, green 2, at 60
// points a second, so the blocks are 180, 240 and 120 points wide. The screen is 402 points wide with the
// playhead at x 201. At 5.5 seconds (`-playhead 3300`) red's left end is at x 51 and green's middle at x 351.
// Green let go 4 points right of red's left end is let go at about 3.07 seconds, after the middle of blue and
// before the middle of red, so it takes the place 2. Each test starts its first launch with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielement/ishittable
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
@MainActor
final class ReorderTests: XCTestCase {
    private let blue = "blue 0+1800 100 v"
    private let red = "red 0+2400 100 v"
    private let green = "green 0+1200 100 v"

    func testAPressAndDragMovesGreenOntoRedAndAnUndoPutsItBack() {
        let app = startReorder(drafts: "fresh")
        let before = playheadValue(app)

        mark("reorder-01-press")
        moveGreenOntoRed(app)
        XCTAssertEqual(values(app), [blue, green, red])
        XCTAssertEqual(playheadValue(app), before)
        XCTAssertTrue(element(app, "editor.clip.2").isSelected)
        screenshot("reorder-01-moved")

        element(app, "editor.undo").tap()
        waitUntil("red second after the undo") { self.value(app, 2) == self.red }
        XCTAssertEqual(values(app), [blue, red, green])
        element(app, "editor.redo").tap()
        waitUntil("green second after the redo") { self.value(app, 2) == self.green }
        XCTAssertEqual(values(app), [blue, green, red])
        app.terminate()

        XCTAssertEqual(draftsInfo(startApp(seed: nil, drafts: "kept")), "1 3+5400+0+1080x30+.")
    }

    /// Red pressed on its right part and held still: the time under the finger would be after the middle of
    /// green, so a move read from the finger would put red last. Read from red's left end it keeps its place.
    func testAPressHeldStillOnTheRightPartOfABlockMovesNothing() {
        let app = startReorder(drafts: "fresh")
        let undo = element(app, "editor.undo")
        XCTAssertFalse(undo.isEnabled)

        element(app, "editor.clip.2").coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).press(forDuration: 1)
        // A tap after the press has an effect to wait for, and is handled after the press.
        let greenBlock = element(app, "editor.clip.3")
        greenBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("editor.clip.3 selected after the tap that follows the press") { greenBlock.isSelected }
        XCTAssertEqual(values(app), [blue, red, green])
        XCTAssertFalse(undo.isEnabled)
    }

    func testAShortPressAndDragScrubsAndMovesNoBlock() {
        let app = startApp(seed: "three-clips", drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertEqual(playheadValue(app), "00:00")

        // A press of 0.1 seconds in the middle of blue, as the scrubs of TimelineTests.
        let start = element(app, "editor.clip.1").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -120, dy: 0)))
        waitUntil("another playhead value after the short press and drag") { self.playheadValue(app) != "00:00" }
        let later = playheadValue(app)
        XCTAssertTrue(["00:01", "00:02", "00:03"].contains(later), later)
        XCTAssertEqual(values(app), [blue, red, green])
    }

    func testAPressAndDragOnTheEndHandleTrimsAndMovesNoBlock() {
        let app = startReorder(drafts: "fresh")
        let redBlock = element(app, "editor.clip.2")
        let end = element(app, "editor.trim.end")
        redBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { redBlock.isSelected && end.exists }

        // The end handle of red lies over the left end of green.
        let start = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: start.withOffset(CGVector(dx: -60, dy: 0)))
        waitUntil("red shorter than 2400 ticks after the drag of its end handle") {
            self.value(app, 2).hasPrefix("red 0+") && self.value(app, 2) != self.red
        }
        print("reorder: after the drag of the end handle editor.clip.2 reads \(value(app, 2))")
        XCTAssertEqual(value(app, 1), blue)
        XCTAssertEqual(value(app, 3), green)
    }

    func testAPressAndDragOnATextBarMovesNoBlock() {
        let app = startApp(seed: "text-box-wide", drafts: "fresh")
        waitForTheEditor(app)
        let blocks = [value(app, 1), value(app, 2)]
        let before = playheadValue(app)
        print("reorder: on text-box-wide the blocks read \(blocks), the playhead \(before)")

        let bar = element(app, "editor.text.1")
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: start.withOffset(CGVector(dx: -150, dy: 0)))
        // A drag that begins on a bar is a scrub, as TextRowTests holds.
        waitUntil("another playhead value after the press and drag on the bar") { self.playheadValue(app) != before }
        XCTAssertEqual([value(app, 1), value(app, 2)], blocks)
    }

    func testInArabicAndSwedishTheMovedStripRunsLeftToRight() {
        for language in ["ar", "sv"] {
            let app = startReorder(language: language, drafts: "fresh")
            moveGreenOntoRed(app)
            XCTAssertEqual(values(app), [blue, green, red])
            let blocks = ["editor.clip.1", "editor.clip.2", "editor.clip.3"].map { element(app, $0) }
            // Blue, green, red from the left, touching.
            XCTAssertEqual(blocks[0].frame.maxX, blocks[1].frame.minX, accuracy: 1)
            XCTAssertEqual(blocks[1].frame.maxX, blocks[2].frame.minX, accuracy: 1)
            XCTAssertLessThan(blocks[0].frame.minX, blocks[1].frame.minX)
            screenshot("reorder-01-moved-" + language)
            app.terminate()
        }
    }

    /// The press and drag of E20: green pressed at its middle for 0.6 seconds and dragged to 4 points right of
    /// the left end of red. Red is read until green stands second, expected within 1 second, failing at 10.
    private func moveGreenOntoRed(_ app: XCUIApplication) {
        let greenBlock = element(app, "editor.clip.3")
        let redBlock = element(app, "editor.clip.2")
        print("reorder: editor.clip.3 hittable at the press: \(greenBlock.isHittable), its frame \(greenBlock.frame)")
        print("reorder: editor.clip.2 frame before the press \(redBlock.frame)")
        let from = greenBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = redBlock.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 4, dy: 0))
        from.press(forDuration: 0.6, thenDragTo: to)
        waitUntil("editor.clip.2 reading green after the press and drag", expected: 1, limit: 10) {
            self.value(app, 2) == self.green
        }
        print("reorder: after the press and drag the blocks read \(values(app))")
    }

    /// Starts on three-clips at 5.5 seconds and waits for the editor: the first seeded start in a fresh
    /// simulator writes the clips first.
    private func startReorder(language: String = "en", drafts: String) -> XCUIApplication {
        let app = startApp(seed: "three-clips", language: language, playhead: 3300, drafts: drafts)
        waitForTheEditor(app)
        return app
    }

    /// Reads until the condition holds, for the effect of a press, a tap or a launch. It is expected within the
    /// seconds given and fails only above the limit, which counts from the end of the first read.
    private func waitUntil(_ what: String, expected: Double = 1, limit: Double = 3, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        let first = waited
        while !holds && waited <= first + limit {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("reorder: waited \(waited) seconds for \(what), expected \(expected), limit \(limit)")
        XCTAssertTrue(holds, what)
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: 10, limit: 30) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("reorder: start.draftsInfo reads " + label)
        return label
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The value of the block at the position, empty when there is none.
    private func value(_ app: XCUIApplication, _ position: Int) -> String {
        element(app, "editor.clip." + String(position)).value as? String ?? ""
    }

    private func values(_ app: XCUIApplication) -> [String] {
        [value(app, 1), value(app, 2), value(app, 3)]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }
}
