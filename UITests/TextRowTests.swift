import XCTest

// The text row of the strip on the landscape seeds: blue 3 seconds, then red 4, at 60 points a second,
// so the two blocks are 180 and 240 points wide. `text-box-wide` has one text, "BOX", from 1 second for
// 1.5 seconds, selected at the start. `text-wide` has one text for the whole video, `two-clips-wide` none.
// The screen is 402 points wide with the playhead at x 201, and a handle of a bar is 24 points wide
// outside its edge. The x values in the comments are worked out from that. The values of the selected
// text are read from `editor.textInfo` by the place of a field: the ninth is "<start ticks>+<length ticks>".
//
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
@MainActor
final class TextRowTests: XCTestCase {
    func testTheStripHasARowOfClipsAndUnderItARowOfTextsWithOneBar() {
        // At the start the blue block is from x 201 to 381 and the bar from x 261 to 351.
        let app = startRow(seed: "text-box-wide")
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")
        let bar = element(app, "editor.text.1")
        XCTAssertTrue(bar.exists)
        guard bar.exists else {
            return
        }

        XCTAssertEqual(region.frame.height, 104, accuracy: 1)
        XCTAssertEqual(blue.frame.height, 56, accuracy: 1)
        XCTAssertEqual(blue.frame.minY - region.frame.minY, 8, accuracy: 1)
        XCTAssertEqual(bar.frame.height, 24, accuracy: 1)
        XCTAssertEqual(bar.frame.minY - region.frame.minY, 72, accuracy: 1)
        // The bar starts at 1 second and is 1.5 seconds long, and shows the first line of the string.
        XCTAssertEqual(bar.frame.minX - blue.frame.minX, 60, accuracy: 1)
        XCTAssertEqual(bar.frame.width, 90, accuracy: 1)
        XCTAssertEqual(shown(on: bar), "BOX")
        XCTAssertFalse(element(app, "editor.text.2").exists)
        screenshot("text-row-01-row")

        // The trim handles of a clip are as high as the clip row.
        tap(blue)
        let start = element(app, "editor.trim.start")
        let end = element(app, "editor.trim.end")
        waitUntil("both trim handles after the tap on the blue block") { start.exists && end.exists }
        guard start.exists, end.exists else {
            return
        }
        for handle in [start, end] {
            XCTAssertEqual(handle.frame.height, 56, accuracy: 1)
            XCTAssertEqual(handle.frame.minY, blue.frame.minY, accuracy: 1)
        }
    }

    func testTheBarOfAWholeTextIsAsWideAsTheClipsAndItsEndCanBeTrimmed() {
        // At 5 seconds the strip is from x -99 to 321, and the end handle of the bar from x 321 to 345.
        let app = startRow(seed: "text-wide", playhead: 3000)
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        let bar = element(app, "editor.text.1")
        XCTAssertTrue(bar.exists)
        guard bar.exists else {
            return
        }

        XCTAssertEqual(bar.frame.width, 420, accuracy: 1)
        XCTAssertEqual(bar.frame.width, blue.frame.width + red.frame.width, accuracy: 1)
        XCTAssertEqual(bar.frame.minX, blue.frame.minX, accuracy: 1)
        // The first of the three lines, on one line.
        XCTAssertEqual(shown(on: bar), "Peace")
        XCTAssertEqual(field(app, 9), "0+4200")

        // A whole text becomes a range: the drag ends at x 273.
        drag(element(app, "editor.textTrim.end"), byPoints: -60)
        waitUntil("a length below 4200 after the drag of the end handle") { (range(app)?.length ?? 4200) < 4200 }
        XCTAssertEqual(range(app)?.start, 0)
        XCTAssertGreaterThanOrEqual(range(app)?.length ?? 0, 60)
        XCTAssertLessThan(bar.frame.width, 420)
    }

    func testABlankTextHasABarAndATapOnEmptyStripRemovesIt() {
        // At 6 seconds the strip is from x -159 to 261, so the 141 points right of the red block are empty.
        let app = startRow(seed: "two-clips-wide", playhead: 3600)
        let region = element(app, "editor.timelineRegion")
        let red = element(app, "editor.clip.2")
        let bar = element(app, "editor.text.1")
        // A project with no text has an empty second row.
        XCTAssertFalse(bar.exists)

        element(app, "editor.addText").tap()
        waitUntil("the bar of the blank text after the tap on the text button") {
            bar.exists && element(app, "editor.textRegion").exists
        }
        guard bar.exists else {
            return
        }
        XCTAssertEqual(bar.frame.width, 420, accuracy: 1)
        XCTAssertEqual(shown(on: bar), "")
        XCTAssertTrue(bar.isSelected)

        // The clip row past the last block. The blank text goes with its bar, as done does it.
        let past = CGVector(dx: (red.frame.maxX + region.frame.maxX) / 2, dy: red.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(past).tap()
        waitUntil("no bar and no selected text after the tap past the last block") {
            !bar.exists && textInfo(app) == "none"
        }
        XCTAssertFalse(element(app, "editor.textRegion").exists)
        XCTAssertFalse(red.isSelected)
    }

    func testATapOnABarSelectsItsTextAndATapOnEmptyStripClears() {
        // At the start the bar is from x 261 to 351, its handles from x 237 to 261 and from x 351 to 375.
        let app = startRow(seed: "text-box-wide")
        let region = element(app, "editor.textRegion")
        let blue = element(app, "editor.clip.1")
        let bar = element(app, "editor.text.1")
        let start = element(app, "editor.textTrim.start")
        let end = element(app, "editor.textTrim.end")
        let clipStart = element(app, "editor.trim.start")
        let clipEnd = element(app, "editor.trim.end")
        let info = "1 naskh 96 255,214,10 centre 960,540 0 ..b 600+900 0"

        // Done leaves nothing selected: the bar stays and has no handle.
        element(app, "text.done").tap()
        waitUntil("no selected text after the tap on done") { textInfo(app) == "none" && !region.exists }
        XCTAssertTrue(bar.exists)
        XCTAssertFalse(bar.isSelected)
        XCTAssertFalse(start.exists)
        XCTAssertFalse(end.exists)

        tapTheMiddle(of: bar)
        waitUntil("the text selected after the tap on its bar, with the panel and both handles") {
            textInfo(app) == info && bar.isSelected && region.exists && start.exists && end.exists
        }
        XCTAssertEqual(textInfo(app), info)
        XCTAssertTrue(element(app, "text.tab.look").isSelected)
        XCTAssertFalse(blue.isSelected)
        assertTheHandlesAreOutsideTheEdges(app, of: bar)
        XCTAssertEqual(bar.label, "Text 1")
        XCTAssertEqual(start.label, "Text start")
        XCTAssertEqual(end.label, "Text end")
        screenshot("text-row-02-handles")

        // A second tap on the selected bar leaves it selected.
        tapTheMiddle(of: bar)
        XCTAssertTrue(bar.isSelected)
        XCTAssertEqual(textInfo(app), info)

        // A tap on a handle of the bar selects no clip and clears nothing.
        tapTheMiddle(of: start)
        XCTAssertTrue(bar.isSelected)
        XCTAssertEqual(textInfo(app), info)
        XCTAssertFalse(blue.isSelected)
        XCTAssertFalse(clipStart.exists)

        // One selection: a clip takes it from the text, and the bar takes it back.
        tap(blue)
        waitUntil("the clip selected after the tap on the blue block, the text no longer") {
            !region.exists && !bar.isSelected && clipStart.exists && clipEnd.exists
        }
        XCTAssertFalse(start.exists)
        XCTAssertFalse(end.exists)
        tapTheMiddle(of: bar)
        waitUntil("the text selected again after the tap on its bar, the clip no longer") {
            !clipStart.exists && !clipEnd.exists && start.exists && end.exists && bar.isSelected
        }
        XCTAssertFalse(blue.isSelected)
        XCTAssertTrue(region.exists)

        // The empty part of the text row, right of the end handle.
        let strip = element(app, "editor.timelineRegion")
        let empty = CGVector(dx: (end.frame.maxX + strip.frame.maxX) / 2, dy: bar.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(empty).tap()
        waitUntil("no selected text after the tap on the empty part of the text row") {
            textInfo(app) == "none" && !region.exists
        }
        XCTAssertTrue(bar.exists)
        XCTAssertFalse(bar.isSelected)
        XCTAssertFalse(start.exists)
        XCTAssertFalse(end.exists)
    }

    func testADragOfTheEndHandleToTheLeftMakesTheBarShorter() {
        // At the start the end handle of the bar is from x 351 to 375, and the drag ends at x 333.
        let app = startRow(seed: "text-box-wide")
        let bar = element(app, "editor.text.1")
        let before = playheadValue(app)
        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(field(app, 9), "600+900")
        let left = bar.frame.minX

        mark("text-row-01-trim-end")
        drag(element(app, "editor.textTrim.end"), byPoints: -30)
        waitUntil("a length below 900 after the drag of the end handle") { (range(app)?.length ?? 900) < 900 }
        XCTAssertEqual(range(app)?.start, 600)
        XCTAssertGreaterThanOrEqual(range(app)?.length ?? 0, 60)
        XCTAssertLessThan(bar.frame.width, 90)
        XCTAssertEqual(bar.frame.minX, left, accuracy: 1)
        XCTAssertTrue(bar.isSelected)
        // The drag was no scrub.
        XCTAssertEqual(playheadValue(app), before)
    }

    func testADragOfTheStartHandleToTheRightMakesTheBarShorterFromTheLeft() {
        // At the start the start handle of the bar is from x 237 to 261, and the drag ends at x 279.
        let app = startRow(seed: "text-box-wide")
        let bar = element(app, "editor.text.1")
        let before = playheadValue(app)
        XCTAssertFalse(before.isEmpty)
        let right = bar.frame.maxX

        mark("text-row-02-trim-start")
        drag(element(app, "editor.textTrim.start"), byPoints: 30)
        waitUntil("a start above 600 after the drag of the start handle") { (range(app)?.start ?? 600) > 600 }
        XCTAssertLessThan(bar.frame.width, 90)
        // The right edge of the bar is where it was.
        XCTAssertEqual(bar.frame.maxX, right, accuracy: 1)
        XCTAssertTrue(bar.isSelected)
        XCTAssertEqual(playheadValue(app), before)
    }

    func testADragPastALimitStopsAtTheShortestTextAndAtTheEndsOfTheProject() {
        // At 2360 ticks the strip starts at x -35: the bar is from x 25 to 115, its start handle from
        // x 1 to 25 and its end handle from x 115 to 139. The drag ends at x 7, 36 points past the
        // shortest text.
        let app = startRow(seed: "text-box-wide", playhead: 2360)
        let region = element(app, "editor.timelineRegion")
        let bar = element(app, "editor.text.1")
        let start = element(app, "editor.textTrim.start")
        let end = element(app, "editor.textTrim.end")

        mark("text-row-03-limits")
        drag(end, byPoints: -120)
        waitUntil("the shortest text after the drag of the end handle past the start") {
            field(app, 9) == "600+60"
        }
        XCTAssertEqual(bar.frame.width, 6, accuracy: 1)
        assertTheHandlesAreOutsideTheEdges(app, of: bar)
        XCTAssertGreaterThanOrEqual(start.frame.minX, region.frame.minX)
        screenshot("text-row-03-shortest")

        // The end handle is now from x 31 to 55. The first drag ends at x 343, short of the end of the
        // project, which is at x 385.
        drag(end, byPoints: 300)
        waitUntil("a longer text after the drag of the end handle to the right") {
            (range(app)?.length ?? 0) > 60
        }
        // A scrub of 150 points in the clip row brings the end handle back to the middle of the screen.
        // The second drag from there goes about 96 points past the end of the project.
        scrub(app, fromX: 0.9, byPoints: -150)
        waitUntil("the end handle with 150 points of screen to its right after the scrub") {
            end.frame.midX > 10 && end.frame.midX < 248
        }
        drag(end, byPoints: 150)
        waitUntil("the end of the project after the drag of the end handle past it") {
            field(app, 9) == "600+3600"
        }

        // A scrub back by 300 points puts the start handle near x 163. The drag goes about 50 points
        // past the start of the strip, and the text lasts the whole video again.
        scrub(app, fromX: 0.1, byPoints: 300)
        waitUntil("the start handle with 110 points of screen to its left after the scrub") {
            start.frame.midX > 115 && start.frame.midX < 390
        }
        drag(start, byPoints: -110)
        waitUntil("the whole video after the drag of the start handle past the start") {
            field(app, 9) == "0+4200"
        }
        XCTAssertEqual(bar.frame.width, 420, accuracy: 1)
    }

    func testADragOnTheBarScrubsAndTheClipHandlesStillWork() {
        // At 2.5 seconds the strip starts at x 51 and the bar is from x 111 to 201. The drag starts in
        // its middle, at x 156, away from both handles, and ends at x 6.
        let app = startRow(seed: "text-box-wide", playhead: 1500)
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        let bar = element(app, "editor.text.1")
        let before = playheadValue(app)
        XCTAssertFalse(before.isEmpty)

        drag(bar, byPoints: -150)
        waitUntil("another playhead value after the drag that began on the bar") { playheadValue(app) != before }
        XCTAssertGreaterThan(playheadValue(app), before)
        XCTAssertEqual(field(app, 9), "600+900")
        XCTAssertTrue(bar.isSelected)

        // The strip now starts near x -99: the red block is from x 81 to 321 and its end handle from
        // x 321 to 345. The drag ends near x 273.
        let clipEnd = element(app, "editor.trim.end")
        tap(red)
        waitUntil("the red block selected after the tap on it, with its end handle") {
            red.isSelected && clipEnd.exists
        }
        drag(clipEnd, byPoints: -60)
        waitUntil("a narrower red block after the drag of its end handle") { red.frame.width < 239 }
        // The bar is as it was.
        XCTAssertEqual(bar.frame.width, 90, accuracy: 1)
        XCTAssertEqual(bar.frame.minX - blue.frame.minX, 60, accuracy: 1)
        XCTAssertEqual(shown(on: bar), "BOX")
    }

    func testInArabicTheBarAndItsHandlesDoNotMirror() {
        let app = startRow(seed: "text-box-wide", language: "ar")
        let blue = element(app, "editor.clip.1")
        let bar = element(app, "editor.text.1")
        XCTAssertTrue(bar.exists)
        guard bar.exists else {
            return
        }

        // The bar begins at the same place, the start handle is at its left edge and the end handle at its right.
        XCTAssertLessThan(blue.frame.minX, element(app, "editor.clip.2").frame.minX)
        XCTAssertEqual(bar.frame.minX - blue.frame.minX, 60, accuracy: 1)
        XCTAssertEqual(bar.frame.width, 90, accuracy: 1)
        assertTheHandlesAreOutsideTheEdges(app, of: bar)
        // The Arabic lines of the word file. The number is written with the digits 0 to 9.
        XCTAssertEqual(bar.label, "النص" + " 1")
        XCTAssertEqual(element(app, "editor.textTrim.start").label, "بداية النص")
        XCTAssertEqual(element(app, "editor.textTrim.end").label, "نهاية النص")
        screenshot("text-row-02-handles-ar")
    }

    /// Reads until the condition holds, for the effect of a tap or a drag. It is expected within a second
    /// and fails only above three: a hosted runner under load can hold the app for seconds.
    private func waitUntil(_ what: String, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !holds && waited <= first + 3 {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("text-row: waited \(waited) seconds for \(what), expected 1, limit 3")
        XCTAssertTrue(holds, what)
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startRow(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
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

    private func textInfo(_ app: XCUIApplication) -> String {
        app.staticTexts["editor.textInfo"].label
    }

    /// The field of `editor.textInfo` at a place counted from 1, or "" when no text is selected.
    private func field(_ app: XCUIApplication, _ place: Int) -> String {
        let fields = textInfo(app).split(separator: " ")
        return fields.count == 10 ? String(fields[place - 1]) : ""
    }

    /// The ninth field as two numbers of ticks, or nil when it is no range.
    private func range(_ app: XCUIApplication) -> (start: Int, length: Int)? {
        let parts = field(app, 9).split(separator: "+")
        guard parts.count == 2, let start = Int(parts[0]), let length = Int(parts[1]) else {
            return nil
        }
        return (start, length)
    }

    /// What is written on a bar: its value. Its label is the word of the app for it.
    private func shown(on bar: XCUIElement) -> String {
        bar.value as? String ?? ""
    }

    /// Taps a block a quarter of its width from its left edge, away from the playhead line.
    private func tap(_ block: XCUIElement) {
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
    }

    private func tapTheMiddle(of element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Presses the middle of a handle or a bar and moves sideways. Minus is to the left.
    private func drag(_ element: XCUIElement, byPoints points: Double) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)))
    }

    /// Drags the strip sideways in the clip row, from a share of the width of the timeline region.
    /// Minus is to the left, which is later.
    private func scrub(_ app: XCUIApplication, fromX: Double, byPoints points: Double) {
        let start = element(app, "editor.timelineRegion")
            .coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.35))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)))
    }

    /// Both handles are there, the start handle ends where the bar starts and the end handle starts
    /// where the bar ends, in the row of the bar.
    private func assertTheHandlesAreOutsideTheEdges(_ app: XCUIApplication, of bar: XCUIElement) {
        let start = element(app, "editor.textTrim.start")
        let end = element(app, "editor.textTrim.end")
        XCTAssertTrue(start.exists)
        XCTAssertTrue(end.exists)
        guard start.exists, end.exists else {
            return
        }
        XCTAssertEqual(start.frame.maxX, bar.frame.minX, accuracy: 1)
        XCTAssertEqual(end.frame.minX, bar.frame.maxX, accuracy: 1)
        XCTAssertGreaterThan(start.frame.width, 0)
        XCTAssertGreaterThan(end.frame.width, 0)
        XCTAssertEqual(start.frame.midY, bar.frame.midY, accuracy: 1)
        XCTAssertEqual(end.frame.midY, bar.frame.midY, accuracy: 1)
    }
}
