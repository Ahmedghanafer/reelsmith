import XCTest

// The two trim handles on the seed three-clips: blue 3 seconds, red 4, green 2, at 60 points a second.
// The screen is 402 points wide with the playhead at x 201, and a handle is 24 points wide outside its edge.
// Each test starts with a playhead that puts the tapped point, the dragged handle and the end of the drag
// on the screen. The x values in the comments are worked out from that.
//
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
@MainActor
final class TrimTests: XCTestCase {
    func testTheSelectedBlockHasAHandleOutsideEachEdge() {
        // At 5 seconds the red block is from x 81 to 321.
        let app = startTrim(seed: "three-clips", playhead: 3000)
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        let start = element(app, "editor.trim.start")
        let end = element(app, "editor.trim.end")
        // No block is selected, so there is no handle.
        XCTAssertFalse(start.exists)
        XCTAssertFalse(end.exists)

        tap(red)
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        XCTAssertTrue(red.isSelected)
        assertTheHandlesAreOutsideTheEdges(app, of: red)
        XCTAssertEqual(start.label, "Trim start")
        XCTAssertEqual(end.label, "Trim end")
        screenshot("m1-9b-trim-handles-01-handles")

        // The start handle lies over the end of the blue block. A tap on it selects nothing.
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(red.isSelected)
        XCTAssertFalse(blue.isSelected)
    }

    func testADragOfTheEndHandleToTheLeftMakesTheBlockShorter() {
        // At 5 seconds the end handle of red is from x 321 to 345, and the drag ends at x 213.
        let app = startTrim(seed: "three-clips", playhead: 3000)
        let red = element(app, "editor.clip.2")
        let green = element(app, "editor.clip.3")
        tap(red)
        waitUntil("the red block selected after the tap on it") { red.isSelected }

        mark("m1-9b-trim-handles-01-trim-end")
        drag(element(app, "editor.trim.end"), byPoints: -120)
        XCTAssertLessThan(red.frame.width, 240)
        // Green follows.
        XCTAssertEqual(green.frame.minX, red.frame.maxX, accuracy: 1)
        XCTAssertTrue(red.isSelected)
        // The drag was no scrub.
        XCTAssertEqual(playheadValue(app), "00:05")
        // It was the end that was cut: the start is still the start of the source, so a drag of the start
        // handle to the left, from x 69 to x 9, gives nothing back.
        let width = red.frame.width
        drag(element(app, "editor.trim.start"), byPoints: -60)
        XCTAssertEqual(red.frame.width, width, accuracy: 1)
        let length = projectLength(app)
        XCTAssertTrue(["00:06", "00:07", "00:08"].contains(length), length)
    }

    func testADragOfTheStartHandleToTheRightMakesTheBlockShorter() {
        // At 5 seconds the start handle of red is from x 57 to 81, and the drag ends at x 189.
        let app = startTrim(seed: "three-clips", playhead: 3000)
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        tap(red)
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        let left = red.frame.minX

        mark("m1-9b-trim-handles-02-trim-start")
        drag(element(app, "editor.trim.start"), byPoints: 120)
        XCTAssertLessThan(red.frame.width, 240)
        // Its left edge stays against blue.
        XCTAssertEqual(red.frame.minX, left, accuracy: 1)
        XCTAssertEqual(red.frame.minX, blue.frame.maxX, accuracy: 1)
        XCTAssertTrue(red.isSelected)
        XCTAssertEqual(playheadValue(app), "00:05")
        // It was the start that was cut: the end is still the end of the source, so a drag of the end
        // handle to the right, from x 213 to x 333, gives nothing back.
        let width = red.frame.width
        drag(element(app, "editor.trim.end"), byPoints: 120)
        XCTAssertEqual(red.frame.width, width, accuracy: 1)
        let length = projectLength(app)
        XCTAssertTrue(["00:06", "00:07", "00:08"].contains(length), length)
    }

    func testADragPastALimitStopsAtTheShortestClipAndAtTheEndOfTheSource() {
        // At 4.5 seconds the end handle of red is from x 351 to 375. The screen has no room for a drag of
        // 600 points, so the drag is 300 points to x 63, which is 66 points past the shortest clip.
        let app = startTrim(seed: "three-clips", playhead: 2700)
        let red = element(app, "editor.clip.2")
        let end = element(app, "editor.trim.end")
        tap(red)
        waitUntil("the red block selected after the tap on it") { red.isSelected }

        mark("m1-9b-trim-handles-03-limits")
        drag(end, byPoints: -300)
        XCTAssertEqual(red.frame.width, 6, accuracy: 1)
        assertTheHandlesAreOutsideTheEdges(app, of: red)
        screenshot("m1-9b-trim-handles-02-shortest")
        XCTAssertEqual(projectLength(app), "00:05")

        // The playhead is now at the end, so the end handle is from x 81 to 105. The drag is 300 points
        // to x 393, which is 66 points past the end of the source.
        drag(end, byPoints: 300)
        XCTAssertEqual(red.frame.width, 240, accuracy: 1)
        XCTAssertEqual(projectLength(app), "00:09")
    }

    func testTheStartHandleOfTheFirstClipCanBeDragged() {
        // At the start the blue block is from x 201 to 381 and its start handle from 177 to 201,
        // left of the strip. The drag ends at x 309.
        let app = startTrim(seed: "three-clips")
        let blue = element(app, "editor.clip.1")
        let start = element(app, "editor.trim.start")
        tap(blue)
        waitUntil("the blue block selected after the tap on it") { blue.isSelected }
        let left = blue.frame.minX

        mark("m1-9b-trim-handles-04-first-clip")
        drag(start, byPoints: 120)
        XCTAssertLessThan(blue.frame.width, 180)
        XCTAssertEqual(blue.frame.minX, left, accuracy: 1)
        XCTAssertTrue(start.exists)
        XCTAssertEqual(start.frame.maxX, blue.frame.minX, accuracy: 1)
        XCTAssertEqual(playheadValue(app), "00:00")
        let length = projectLength(app)
        XCTAssertTrue(["00:06", "00:07", "00:08"].contains(length), length)
    }

    func testTheEndHandleOfTheLastClipCanBeDragged() {
        // At 7 seconds the green block is from x 201 to 321 and its end handle from 321 to 345,
        // right of the strip. The drag ends at x 273.
        let app = startTrim(seed: "three-clips", playhead: 4200)
        let green = element(app, "editor.clip.3")
        let end = element(app, "editor.trim.end")
        tap(green)
        waitUntil("the green block selected after the tap on it") { green.isSelected }
        let left = green.frame.minX

        mark("m1-9b-trim-handles-05-last-clip")
        drag(end, byPoints: -60)
        XCTAssertLessThan(green.frame.width, 120)
        XCTAssertEqual(green.frame.minX, left, accuracy: 1)
        XCTAssertTrue(end.exists)
        XCTAssertEqual(end.frame.minX, green.frame.maxX, accuracy: 1)
        XCTAssertEqual(playheadValue(app), "00:07")
        let length = projectLength(app)
        XCTAssertTrue(["00:07", "00:08"].contains(length), length)
    }

    func testInArabicTheHandlesDoNotMirror() {
        let app = startTrim(seed: "three-clips", language: "ar", playhead: 3000)
        let red = element(app, "editor.clip.2")
        tap(red)
        waitUntil("the red block selected after the tap on it") { red.isSelected }

        // The start handle is still at the left edge and the end handle at the right.
        assertTheHandlesAreOutsideTheEdges(app, of: red)
        // The Arabic lines of the word file.
        XCTAssertEqual(element(app, "editor.trim.start").label, "قص البداية")
        XCTAssertEqual(element(app, "editor.trim.end").label, "قص النهاية")
        screenshot("m1-9b-trim-handles-01-handles-ar")
    }

    func testATapOnEmptyStripClearsTheSelectionAndADragKeepsIt() {
        // At 1.5 seconds the strip starts at x 111, so the 111 points left of the blue block are empty.
        // The red block is from x 291 to 531, tapped at x 351, and its start handle is from x 267 to 291.
        let app = startTrim(seed: "three-clips", playhead: 900)
        let red = element(app, "editor.clip.2")
        let start = element(app, "editor.trim.start")
        let end = element(app, "editor.trim.end")
        let delete = element(app, "editor.delete")
        // The middle of the height at x 40, left of the first block.
        let empty = element(app, "editor.timelineRegion")
            .coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let before = playheadValue(app)
        XCTAssertFalse(before.isEmpty)

        // With nothing selected a tap on empty strip changes nothing.
        empty.tap()
        // A pause, never a limit: nothing is expected to change.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(red.isSelected)
        XCTAssertFalse(start.exists)
        XCTAssertFalse(delete.isEnabled)
        XCTAssertEqual(playheadValue(app), before)

        tap(red)
        waitUntil("the red block selected after the tap on it") { red.isSelected && start.exists && end.exists }
        XCTAssertTrue(delete.isEnabled)

        empty.tap()
        waitUntil("nothing selected after the tap left of the first block") { !red.isSelected }
        XCTAssertFalse(element(app, "editor.clip.1").isSelected)
        XCTAssertFalse(element(app, "editor.clip.3").isSelected)
        XCTAssertFalse(start.exists)
        XCTAssertFalse(end.exists)
        XCTAssertFalse(delete.isEnabled)
        XCTAssertEqual(playheadValue(app), before)
        screenshot("m1-14-clear-selection-01-cleared")

        // The band above the row of blocks: 4 points below the top of the strip view, which is the top
        // of the playhead line, above the point of the red block that was tapped. The app fills the screen,
        // so its top left corner is the zero point of the frames.
        tap(red)
        waitUntil("the red block selected again") { red.isSelected }
        let band = CGVector(
            dx: red.frame.minX + red.frame.width / 4, dy: element(app, "editor.playhead").frame.minY + 4)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(band).tap()
        waitUntil("nothing selected after the tap in the band above the blocks") { !red.isSelected }
        XCTAssertFalse(start.exists)
        XCTAssertFalse(end.exists)
        XCTAssertEqual(playheadValue(app), before)

        // A drag that starts on the same empty point scrubs and keeps the selection. 200 points to
        // the right is past the start, which is 90 points away.
        tap(red)
        waitUntil("the red block selected before the drag") { red.isSelected }
        empty.press(forDuration: 0.1, thenDragTo: empty.withOffset(CGVector(dx: 200, dy: 0)))
        waitUntil("the playhead at 00:00 after the drag") { playheadValue(app) == "00:00" }
        XCTAssertTrue(red.isSelected)
        XCTAssertTrue(start.exists)
        XCTAssertTrue(end.exists)
        XCTAssertTrue(delete.isEnabled)
    }

    /// Reads until the condition holds, for the effect of a tap or a drag. It is expected within a second
    /// and fails only above three: a hosted runner under load can hold the app for seconds.
    private func waitUntil(_ what: String, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        while !holds && waited <= 3 {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("m1-14-clear-selection: waited \(waited) seconds for \(what), expected 1")
        XCTAssertTrue(holds, what)
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startTrim(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// Taps a block a quarter of its width from its left edge, which is on the screen in every test here
    /// and away from the playhead line.
    private func tap(_ block: XCUIElement) {
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
    }

    /// Presses the middle of a handle and moves sideways. Minus is to the left.
    private func drag(_ handle: XCUIElement, byPoints points: Double) {
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)))
    }

    /// The project length: the strip is dragged to its end and the playhead is read. The drags start at
    /// x 362, where no handle lies in any test here.
    private func projectLength(_ app: XCUIApplication) -> String {
        for _ in 0..<3 {
            let start = element(app, "editor.timelineRegion")
                .coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -320, dy: 0)))
        }
        return playheadValue(app)
    }

    /// Both handles are there, the start handle ends where the block starts and the end handle starts
    /// where the block ends, so neither covers the block or the other.
    private func assertTheHandlesAreOutsideTheEdges(_ app: XCUIApplication, of block: XCUIElement) {
        let start = element(app, "editor.trim.start")
        let end = element(app, "editor.trim.end")
        XCTAssertTrue(start.exists)
        XCTAssertTrue(end.exists)
        guard start.exists, end.exists else {
            return
        }
        XCTAssertEqual(start.frame.maxX, block.frame.minX, accuracy: 1)
        XCTAssertEqual(end.frame.minX, block.frame.maxX, accuracy: 1)
        XCTAssertLessThan(start.frame.minX, end.frame.minX)
        XCTAssertGreaterThan(start.frame.width, 0)
        XCTAssertGreaterThan(end.frame.width, 0)
    }
}
