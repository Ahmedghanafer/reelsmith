import XCTest

// The whole path in one test: a cold start, two videos from the system picker, a split, a delete, a trim,
// playback to the end, an export and a relaunch. Then the same three states in Arabic and in Swedish.
// The screen is 402 points wide with the playhead at x 201, the scale is 60 points a second, and a trim
// handle is 24 points wide outside its edge. No test reads a pixel: what the preview shows is judged on
// the screenshots and in the recording.
//
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/identifier
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider
// https://developer.apple.com/documentation/xctest/xcuielementquery/matching(identifier:)
// https://developer.apple.com/documentation/xctest/xcuielementquery/element(boundby:)
// https://developer.apple.com/documentation/xctest/xcuielementquery/allelementsboundbyindex
// https://developer.apple.com/documentation/xctest/xctexpectfailure(_:options:failingblock:)
// https://developer.apple.com/documentation/xctest/xctexpectedfailure/options/isstrict
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholePathTests: XCTestCase {
    func testTheWholePathFromAColdStartToASavedVideo() {
        mark("m1-12-whole-path-01-path")
        var app = startApp(seed: nil)
        assertTheStartScreen(app)
        screenshot("m1-12-whole-path-01-start")

        // Blue then red from the system picker. When the picker is not driven the walk goes on from the seed.
        let stopped = tryThePicker(app, picture: "m1-12-whole-path-02-picker")
        if let stopped {
            print("m1-12-whole-path: picker not driven: " + stopped)
            app = startApp(seed: "two-clips-wide")
        } else {
            print("m1-12-whole-path: picker driven")
        }

        // The editor: blue 3 seconds and red 4 on the 16:9 canvas.
        XCTAssertTrue(element(app, "editor.root").waitForExistence(timeout: 90))
        XCTAssertEqual(element(app, "editor.clip.1").frame.width, 180, accuracy: 1)
        XCTAssertEqual(element(app, "editor.clip.2").frame.width, 240, accuracy: 1)
        XCTAssertFalse(element(app, "editor.clip.3").exists)
        let wide = element(app, "editor.picture").frame
        XCTAssertGreaterThan(wide.width, wide.height)
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:07")
        pauseForThePicture()
        screenshot("m1-12-whole-path-03-editor")

        // The split. Nothing is selected, so no handle lies on the strip. 84 points to the left is 1.4 seconds.
        scrub(app, fromX: 0.5, byPoints: -84)
        wait(for: "the playhead at 00:01 or 00:02 after the drag", expected: 1) {
            ["00:01", "00:02"].contains(playheadValue(app))
        }
        element(app, "editor.split").tap()
        wait(for: "three blocks after the split", expected: 1) { element(app, "editor.clip.3").exists }
        XCTAssertFalse(element(app, "editor.clip.4").exists)
        XCTAssertEqual(
            element(app, "editor.clip.1").frame.width + element(app, "editor.clip.2").frame.width, 180, accuracy: 1)
        pauseForThePicture()
        screenshot("m1-12-whole-path-04-split")

        // The delete of the first block, which ends under the playhead, so its middle is on the screen.
        element(app, "editor.clip.1").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        element(app, "editor.delete").tap()
        wait(for: "two blocks after the delete", expected: 1) { !element(app, "editor.clip.3").exists }
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        let afterDelete = timeSides(app).last ?? ""
        XCTAssertTrue(["00:04", "00:05", "00:06"].contains(afterDelete), afterDelete)
        pauseForThePicture()
        screenshot("m1-12-whole-path-05-delete")

        // The delete cleared the selection, so again no handle lies on the strip. To the end, then to the start.
        for _ in 0..<2 {
            scrub(app, fromX: 0.9, byPoints: -320)
        }
        wait(for: "the playhead at the end of the strip", expected: 1) { theTwoSidesAreTheSame(app) }
        pauseForThePicture()
        for _ in 0..<2 {
            scrub(app, fromX: 0.1, byPoints: 320)
        }
        wait(for: "the playhead back at 00:00", expected: 1) { playheadValue(app) == "00:00" }
        pauseForThePicture()

        // The trim. Still nothing is selected: the strip is dragged until the end of the red block is
        // 74 points left of the right edge, so its end handle is on the screen with 300 points of room.
        let region = element(app, "editor.timelineRegion")
        let red = element(app, "editor.clip.2")
        scrub(app, fromX: 0.95, byPoints: Double(region.frame.maxX - 74 - red.frame.maxX))
        // A quarter of its width from its left edge, away from the playhead line.
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        let end = element(app, "editor.trim.end")
        XCTAssertTrue(end.waitForExistence(timeout: 3))
        let handle = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 234 points reach the shortest clip, so 300 is well past the limit.
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: -300, dy: 0)))
        // The trim below the playhead moved the strip, so the frame is read again.
        wait(for: "the red block at its shortest after the trim", expected: 1) { red.frame.width < 7.5 }
        XCTAssertEqual(red.frame.width, 6, accuracy: 1)
        let afterTrim = timeSides(app).last ?? ""
        XCTAssertTrue(["00:00", "00:01", "00:02"].contains(afterTrim), afterTrim)
        pauseForThePicture()
        screenshot("m1-12-whole-path-06-trim")

        // Red is still selected and its handles lie at x 171 to 225. The drags start at x 40.
        for _ in 0..<2 {
            scrub(app, fromX: 0.1, byPoints: 320)
        }
        wait(for: "the playhead back at 00:00 after the trim", expected: 1) { playheadValue(app) == "00:00" }
        pauseForThePicture()
        element(app, "editor.play").tap()
        wait(for: "the same time on both sides of the slash", expected: 3) { theTwoSidesAreTheSame(app) }
        // The rest of the last second.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(theTwoSidesAreTheSame(app), element(app, "editor.time").label)

        // The export. The wave run grants the right to add to Photos, so no question is expected.
        element(app, "editor.export").tap()
        let done = element(app, "export.done")
        wait(for: "export.done after the export", expected: 30) { done.exists }
        screenshot("m1-12-whole-path-07-saved")
        done.tap()

        // The relaunch: nothing of the edit and no project to reopen.
        app.terminate()
        app = startApp(seed: nil)
        assertTheStartScreen(app)
        screenshot("m1-12-whole-path-08-relaunch")

        // The chosen shape reaches the editor, only when the picker was driven above.
        guard stopped == nil else {
            print("m1-12-whole-path: the portrait start is skipped, the picker was not driven")
            return
        }
        element(app, "start.portrait").tap()
        if let stoppedAgain = tryThePicker(app, picture: nil) {
            print("m1-12-whole-path: picker not driven at the portrait start: " + stoppedAgain)
            return
        }
        let tall = element(app, "editor.picture").frame
        XCTAssertGreaterThan(tall.height, tall.width)
        pauseForThePicture()
        screenshot("m1-12-whole-path-12-portrait")
    }

    func testInArabicTheThreeStatesMirrorWhereTheyShould() {
        assertTheThreeStates(language: "ar", mirrored: true)
    }

    func testInSwedishTheThreeStatesShow() {
        assertTheThreeStates(language: "sv", mirrored: false)
    }

    /// The start screen, the editor on two-clips with the red block selected, and the saved panel.
    /// The start screen and the row of tools follow the language. The preview, the strip, the handles
    /// and the time label never mirror. The panel is in the middle and is judged on its picture.
    private func assertTheThreeStates(language: String, mirrored: Bool) {
        var app = startApp(seed: nil, language: language)
        assertTheStartScreen(app)
        let landscape = element(app, "start.landscape").frame.minX
        let portrait = element(app, "start.portrait").frame.minX
        // The leading shape is first.
        XCTAssertEqual(landscape > portrait, mirrored)
        screenshot("m1-12-whole-path-09-start-" + language)

        // At 5 seconds the red block is from x 81 to 321, so both handles are on the screen.
        app = startApp(seed: "two-clips", language: language, playhead: 3000)
        XCTAssertTrue(element(app, "editor.root").waitForExistence(timeout: 90))
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        XCTAssertTrue(red.isSelected)
        // Split is the leading button of the row.
        let split = element(app, "editor.split").frame.minX
        let delete = element(app, "editor.delete").frame.minX
        XCTAssertEqual(split > delete, mirrored)
        // Fixed left to right in every language.
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertEqual(element(app, "editor.time").label, "00:05 / 00:07")
        XCTAssertLessThan(blue.frame.minX, red.frame.minX)
        XCTAssertEqual(element(app, "editor.trim.start").frame.maxX, red.frame.minX, accuracy: 1)
        XCTAssertEqual(element(app, "editor.trim.end").frame.minX, red.frame.maxX, accuracy: 1)
        pauseForThePicture()
        screenshot("m1-12-whole-path-10-editor-" + language)

        element(app, "editor.export").tap()
        wait(for: "export.done after the export", expected: 30) { element(app, "export.done").exists }
        screenshot("m1-12-whole-path-11-saved-" + language)
    }

    /// The title, the two shapes with landscape chosen, the button, and no editor.
    private func assertTheStartScreen(_ app: XCUIApplication) {
        XCTAssertTrue(element(app, "start.newProject").waitForExistence(timeout: 60))
        XCTAssertTrue(element(app, "start.title").exists)
        XCTAssertTrue(element(app, "start.landscape").isSelected)
        XCTAssertTrue(element(app, "start.portrait").exists)
        XCTAssertFalse(element(app, "start.portrait").isSelected)
        XCTAssertFalse(element(app, "editor.root").exists)
    }

    /// One try at the system picker from the start screen. Nil when the editor opened with blue then red,
    /// else the step that failed. The picker alone never fails the walk: a failure inside the try is expected.
    private func tryThePicker(_ app: XCUIApplication, picture: String?) -> String? {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        return XCTExpectFailure("The picker alone never fails the walk.", options: options) {
            drivePicker(app, picture: picture)
        }
    }

    /// Taps `start.newProject`, chooses blue then red and confirms. The picker runs outside the app, so its
    /// controls read as not hittable and are tapped by coordinate. They carry no identifier of ours and
    /// are found by the system's own identifier, by kind and by place, never by a word.
    private func drivePicker(_ app: XCUIApplication, picture: String?) -> String? {
        let newProject = element(app, "start.newProject")
        guard newProject.exists else {
            return "start.newProject was not there"
        }
        newProject.tap()

        // The videos are the cells of the picker's grid, which the system names PXGGridLayout-Info.
        // The grid lists red first and blue second.
        let cells = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info")
        let red = cells.element(boundBy: 0)
        let blue = cells.element(boundBy: 1)
        guard red.waitForExistence(timeout: 40) else {
            return "no cell of the picker's grid came within 40 seconds"
        }
        guard blue.waitForExistence(timeout: 10) else {
            return "the picker's grid held one cell, two are needed"
        }
        print("m1-12-whole-path: cell 1 of the picker reads: " + red.label)
        print("m1-12-whole-path: cell 2 of the picker reads: " + blue.label)
        let redFrame = red.frame
        let blueFrame = blue.frame
        print("m1-12-whole-path: the cells are at \(redFrame) and \(blueFrame)")
        guard redFrame.width > 1, redFrame.height > 1, blueFrame.width > 1, blueFrame.height > 1 else {
            return "a cell of the picker's grid had no frame to tap"
        }
        blue.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)
        if let picture {
            screenshot(picture)
        }

        // The button that confirms: of the buttons above the grid, the one furthest to the right.
        let top = min(redFrame.minY, blueFrame.minY)
        var confirm: XCUIElement?
        var edge: CGFloat = 0
        for button in app.buttons.allElementsBoundByIndex {
            let frame = button.frame
            let identifier = button.identifier
            if identifier.hasPrefix("start.") || frame.isEmpty || frame.midY > top {
                continue
            }
            print("m1-12-whole-path: a button above the grid at \(frame), identifier: " + identifier)
            if frame.maxX > edge {
                confirm = button
                edge = frame.maxX
            }
        }
        guard let confirm else {
            print(app.debugDescription)
            return "no button above the picker's grid was found"
        }
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        guard element(app, "editor.root").waitForExistence(timeout: 60) else {
            print(app.debugDescription)
            return "the editor did not open within 60 seconds of the tap on the right button above the grid"
        }
        // A block ends with the length of its clip: blue is 3 seconds long and red 4.
        let second = element(app, "editor.clip.2")
        guard second.waitForExistence(timeout: 10) else {
            return "the editor opened with fewer than two blocks"
        }
        let lengths = String(element(app, "editor.clip.1").label.suffix(5)) + " then " + String(second.label.suffix(5))
        guard lengths == "00:03 then 00:04" else {
            return "the editor opened with " + lengths + ", and blue then red is 00:03 then 00:04"
        }
        return nil
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// The two times of `editor.time`, as in "00:02" and "00:07" of "00:02 / 00:07".
    private func timeSides(_ app: XCUIApplication) -> [String] {
        element(app, "editor.time").label.components(separatedBy: " / ")
    }

    private func theTwoSidesAreTheSame(_ app: XCUIApplication) -> Bool {
        let sides = timeSides(app)
        return sides.count == 2 && sides[0] == sides[1]
    }

    /// Drags the strip sideways from a point of the timeline region. Minus is to the left, which is later.
    /// After a selection the start must be a point where no handle lies.
    private func scrub(_ app: XCUIApplication, fromX: Double, byPoints points: Double) {
        let start = element(app, "editor.timelineRegion")
            .coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)))
    }

    /// Reads until the condition holds. Prints the seconds it waited and fails only above three times
    /// the expected seconds: a hosted runner under load can hold the app for seconds.
    private func wait(for what: String, expected: Double, _ reached: () -> Bool) {
        let started = Date()
        var waited: Double = 0
        var holds = reached()
        while !holds && waited <= 3 * expected {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("m1-12-whole-path: waited \(waited) seconds for \(what), expected \(expected)")
        XCTAssertTrue(holds, what)
    }

    /// No element says when a frame is drawn, so a picture of the preview is taken two seconds after
    /// the playhead came to rest. This is a pause, never a limit.
    private func pauseForThePicture() {
        Thread.sleep(forTimeInterval: 2)
    }
}
