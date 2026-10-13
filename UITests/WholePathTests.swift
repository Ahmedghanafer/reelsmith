import XCTest

// The whole path in one test: a cold start, two videos from the system picker, a split, a delete, a trim,
// playback to the end, an export and a relaunch. Then the same three states in Arabic and in Swedish.
// The screen is 402 points wide with the playhead at x 201, the scale is 60 points a second, and a trim
// handle is 24 points wide outside its edge. This test reads no pixel: what the preview shows is judged on
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
// https://developer.apple.com/documentation/xctest/xcuielementsnapshotproviding/snapshot()
// https://developer.apple.com/documentation/xctest/xcuielementsnapshot/children
// https://developer.apple.com/documentation/xctest/xcuielementattributes/elementtype
// https://developer.apple.com/documentation/xctest/xctestcase/set_up_and_tear_down_state_in_your_tests
// https://developer.apple.com/documentation/xctest/xctest/name
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholePathTests: XCTestCase {
    /// Set by the last statement of the walk. A walk that ended before it is failed in `tearDown`.
    private var walkFinished = false
    /// The whole tree of the picker is printed once for a test.
    private var treePrinted = false

    /// A walk that did not reach its last line fails here, whatever ended it.
    override func tearDown() async throws {
        if name.contains("testTheWholePathFromAColdStartToASavedVideo") && !walkFinished {
            XCTFail("The walk ended before its last line: it did not walk the whole path.")
        }
        try await super.tearDown()
    }

    func testTheWholePathFromAColdStartToASavedVideo() {
        mark("m1-12-whole-path-01-path")
        let began = Date()
        var app = startApp(seed: nil)
        assertTheStartScreen(app)
        screenshot("m1-12-whole-path-01-start")

        // Blue then red from the system picker. When the picker is not driven the walk goes on from the seed.
        let stopped = drivePicker(app, picture: "m1-12-whole-path-02-picker")
        if let stopped {
            print("m1-12-whole-path: picker not driven: " + stopped)
            app = startApp(seed: "two-clips-wide")
            waitForTheEditor(app)
        } else {
            print("m1-12-whole-path: picker driven")
        }

        // The editor: blue 3 seconds and red 4 on the 16:9 canvas. After the picker its own wait found it.
        XCTAssertEqual(element(app, "editor.clip.1").frame.width, 180, accuracy: 1)
        XCTAssertEqual(element(app, "editor.clip.2").frame.width, 240, accuracy: 1)
        XCTAssertFalse(element(app, "editor.clip.3").exists)
        let wide = element(app, "editor.picture").frame
        XCTAssertGreaterThan(wide.width, wide.height)
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:07")
        pauseForThePicture()
        screenshot("m1-12-whole-path-03-editor")

        // The split. Nothing is selected, so no handle lies on the strip. The strip moves about 10 points
        // less than the drag, so the cut is near 1.2 seconds.
        scrub(app, fromX: 0.5, byPoints: -84)
        waitUntil("the playhead at 00:01 or 00:02 after the drag", expected: 1) {
            ["00:01", "00:02"].contains(playheadValue(app))
        }
        element(app, "editor.split").tap()
        waitUntil("three blocks after the split", expected: 1) { element(app, "editor.clip.3").exists }
        XCTAssertFalse(element(app, "editor.clip.4").exists)
        XCTAssertEqual(
            element(app, "editor.clip.1").frame.width + element(app, "editor.clip.2").frame.width, 180, accuracy: 1)
        pauseForThePicture()
        screenshot("m1-12-whole-path-04-split")

        // The delete of the first block, which ends under the playhead, so its middle is on the screen.
        element(app, "editor.clip.1").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the first block selected after the tap on it", expected: 1) {
            element(app, "editor.clip.1").isSelected
        }
        XCTAssertTrue(element(app, "editor.clip.1").isSelected)
        element(app, "editor.delete").tap()
        waitUntil("two blocks after the delete", expected: 1) { !element(app, "editor.clip.3").exists }
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        let afterDelete = timeSides(app).last ?? ""
        XCTAssertTrue(["00:04", "00:05", "00:06"].contains(afterDelete), afterDelete)
        pauseForThePicture()
        screenshot("m1-12-whole-path-05-delete")

        // The delete cleared the selection, so again no handle lies on the strip. To the end, then to the start.
        for _ in 0..<2 {
            scrub(app, fromX: 0.9, byPoints: -320)
        }
        waitUntil("the playhead at the end of the strip", expected: 1) { theTwoSidesAreTheSame(app) }
        pauseForThePicture()
        for _ in 0..<2 {
            scrub(app, fromX: 0.1, byPoints: 320)
        }
        waitUntil("the playhead back at 00:00", expected: 1) { playheadValue(app) == "00:00" }
        pauseForThePicture()

        // The trim. Still nothing is selected. The drag aims the end of the red block 74 points left of the
        // right edge, and the strip moves about 10 points less, so the end stands about 64 points left of it:
        // its end handle is on the screen with 300 points of room.
        let region = element(app, "editor.timelineRegion")
        let red = element(app, "editor.clip.2")
        scrub(app, fromX: 0.95, byPoints: Double(region.frame.maxX - 74 - red.frame.maxX))
        // The tap is placed from the frame of the block, so the frame is read only after the drag has moved it.
        waitUntil("the end of the red block on the screen after the drag", expected: 1) {
            red.frame.maxX < region.frame.maxX - 24
        }
        // A quarter of its width from its left edge, away from the playhead line.
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it", expected: 1) { red.isSelected }
        let end = element(app, "editor.trim.end")
        XCTAssertTrue(end.waitForExistence(timeout: 3))
        let handle = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 234 points reach the shortest clip, so 300 is well past the limit.
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: -300, dy: 0)))
        // The trim below the playhead moved the strip, so the frame is read again.
        waitUntil("the red block at its shortest after the trim", expected: 1) { red.frame.width < 7.5 }
        // The handle draws the width before the trim reaches the store, so the label is waited for too.
        waitUntil("00:00, 00:01 or 00:02 after the slash after the trim", expected: 1) {
            ["00:00", "00:01", "00:02"].contains(timeSides(app).last ?? "")
        }
        XCTAssertEqual(red.frame.width, 6, accuracy: 1)
        pauseForThePicture()
        screenshot("m1-12-whole-path-06-trim")

        // Red is still selected and its handles lie at x 171 to 225. The drags start at x 40.
        for _ in 0..<2 {
            scrub(app, fromX: 0.1, byPoints: 320)
        }
        waitUntil("the playhead back at 00:00 after the trim", expected: 1) { playheadValue(app) == "00:00" }
        pauseForThePicture()
        element(app, "editor.play").tap()
        waitUntil("the same time on both sides of the slash", expected: 3) { theTwoSidesAreTheSame(app) }
        // The rest of the last second.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(theTwoSidesAreTheSame(app), element(app, "editor.time").label)
        // The two sides read the same through the whole last second. At the end there is nothing to split,
        // and a stop earlier inside the blue clip would leave the button enabled.
        XCTAssertFalse(element(app, "editor.split").isEnabled)

        // The export. The wave run grants the right to add to Photos, so no question is expected.
        element(app, "editor.export").tap()
        let done = element(app, "export.done")
        waitUntil("export.done after the export", expected: 30) { done.exists }
        screenshot("m1-12-whole-path-07-saved")
        done.tap()

        // The relaunch: nothing of the edit and no project to reopen.
        app.terminate()
        app = startApp(seed: nil)
        assertTheStartScreen(app)
        screenshot("m1-12-whole-path-08-relaunch")

        // The chosen shape reaches the editor, only when the picker was driven above.
        if stopped != nil {
            print("m1-12-whole-path: the portrait start is skipped, the picker was not driven")
        } else {
            element(app, "start.portrait").tap()
            if let stoppedAgain = drivePicker(app, picture: nil) {
                print("m1-12-whole-path: picker not driven at the portrait start: " + stoppedAgain)
            } else {
                let tall = element(app, "editor.picture").frame
                XCTAssertGreaterThan(tall.height, tall.width)
                pauseForThePicture()
                screenshot("m1-12-whole-path-12-portrait")
            }
        }

        // A run in which this line is missing did not walk, whatever its result says.
        let seconds = String(Int(Date().timeIntervalSince(began)))
        print("m1-12-whole-path: walk finished, " + (stopped == nil ? "driven" : "not driven") + ", " + seconds
            + " seconds")
        walkFinished = true
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
        waitForTheEditor(app)
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it", expected: 1) { red.isSelected }
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
        waitUntil("export.done after the export", expected: 30) { element(app, "export.done").exists }
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
    /// else the step that found nothing, and the walk then goes on from the seed. A read or a tap that
    /// raises fails the test like any other. The try stood inside an expected failure before, and that is
    /// gone: an expected failure, once raised inside its closure, also swallowed everything after it in
    /// that test, the failure of `tearDown` included, so a walk that had not walked counted as passed.
    ///
    /// Taps `start.newProject`, chooses blue then red and confirms. The picker runs outside the app, so its
    /// controls read as not hittable and are tapped by coordinate, in the middle of their frames. They carry
    /// no identifier of ours and are found by the system's own identifier, by kind and by place, never by a word.
    private func drivePicker(_ app: XCUIApplication, picture: String?) -> String? {
        let newProject = element(app, "start.newProject")
        guard newProject.exists else {
            return "start.newProject was not there"
        }
        newProject.tap()

        // The videos are the cells of the picker's grid, which the system names PXGGridLayout-Info.
        // The grid lists the newest first. The wave run puts blue into the library and then red, and every
        // video an export saved is newer, so blue is the last cell and red the one before it.
        let cells = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info")
        guard cells.firstMatch.waitForExistence(timeout: 40) else {
            return "no cell of the picker's grid came within 40 seconds"
        }
        // The other cells come with the first one. This is a pause, never a limit.
        Thread.sleep(forTimeInterval: 2)
        // The cells are read from one snapshot, in the order of the tree: of the scroll views, the one that
        // holds the most of them.
        guard let before = try? app.snapshot() else {
            return "no snapshot of the picker's grid could be taken"
        }
        var grid: [any XCUIElementSnapshot] = []
        for view in flattened(before) where view.elementType == .scrollView {
            let found = flattened(view).filter { $0.elementType == .image && $0.identifier == "PXGGridLayout-Info" }
            if found.count > grid.count {
                grid = found
            }
        }
        let count = grid.count
        print("m1-12-whole-path: the picker's grid holds " + String(count) + " cells")
        guard count >= 2 else {
            return "the picker's grid held " + String(count) + " cell, two are needed"
        }
        let first = grid[0]
        let red = grid[count - 2]
        let blue = grid[count - 1]
        print("m1-12-whole-path: the cell before the last reads: " + red.label)
        print("m1-12-whole-path: the last cell reads: " + blue.label)
        let redFrame = red.frame
        let blueFrame = blue.frame
        print("m1-12-whole-path: the cells are at \(redFrame) and \(blueFrame)")
        guard redFrame.width > 1, redFrame.height > 1, blueFrame.width > 1, blueFrame.height > 1 else {
            return "a cell of the picker's grid had no frame to tap"
        }
        let top = min(first.frame.minY, redFrame.minY, blueFrame.minY)
        // A tap may change the grid, so every later tap goes to a place read before the first one.
        tap(app, theMiddleOf: blueFrame)
        Thread.sleep(forTimeInterval: 1)
        tap(app, theMiddleOf: redFrame)
        Thread.sleep(forTimeInterval: 2)
        if let picture {
            screenshot(picture)
        }

        // The whole tree once for a test, for the log of the run, and one snapshot of it for the search:
        // the picker changes after a choice, and a snapshot cannot change under the search.
        if !treePrinted {
            print(app.debugDescription)
            treePrinted = true
        }
        guard let tree = try? app.snapshot() else {
            return "no snapshot of the picker could be taken"
        }
        let all = flattened(tree).filter { !$0.identifier.hasPrefix("start.") && $0.frame.width > 1 }
        // The bar of the picker is the row of its topmost button.
        let bar = all.filter { $0.elementType == .button && $0.frame.midY < top }
            .min { $0.frame.minY < $1.frame.minY }
        guard let bar else {
            return "no button above the picker's grid was found"
        }
        // The control that confirms is found by place and by no word: of the small elements of any kind
        // in the row of the bar, the one furthest to the right, when it lies in the right third of the screen.
        let row = all.filter { abs($0.frame.midY - bar.frame.midY) <= 24 && $0.frame.width <= 120 }
        for one in row {
            print("m1-12-whole-path: in the bar of the picker, kind \(one.elementType.rawValue) at \(one.frame): "
                + one.label)
        }
        let confirm = row.filter { $0.frame.midX > tree.frame.width * 2 / 3 }
            .max { $0.frame.maxX < $1.frame.maxX }
        guard let confirm else {
            return "no element was found on the right of the picker's bar"
        }
        print("m1-12-whole-path: tapped to confirm, kind \(confirm.elementType.rawValue) at \(confirm.frame): "
            + confirm.label)
        tap(app, theMiddleOf: confirm.frame)

        guard element(app, "editor.root").waitForExistence(timeout: 60) else {
            return "the editor did not open within 60 seconds of the tap on the right of the picker's bar"
        }
        // A block ends with the length of its clip: blue is 3 seconds long and red 4.
        guard element(app, "editor.clip.2").waitForExistence(timeout: 10), let editor = try? app.snapshot() else {
            return "the editor opened with fewer than two blocks"
        }
        let blocks = flattened(editor)
        let one = blocks.first { $0.identifier == "editor.clip.1" }?.label ?? ""
        let two = blocks.first { $0.identifier == "editor.clip.2" }?.label ?? ""
        let lengths = String(one.suffix(5)) + " then " + String(two.suffix(5))
        guard lengths == "00:03 then 00:04" else {
            return "the editor opened with " + lengths + ", and blue then red is 00:03 then 00:04"
        }
        return nil
    }

    /// Every element of a snapshot, the element itself first.
    private func flattened(_ node: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        var all: [any XCUIElementSnapshot] = [node]
        for child in node.children {
            all += flattened(child)
        }
        return all
    }

    /// Taps the screen in the middle of a frame that was read from an element. The app fills the screen,
    /// so its top left corner is the zero point of the frames.
    private func tap(_ app: XCUIApplication, theMiddleOf frame: CGRect) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .tap()
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
    private func waitUntil(_ what: String, expected: Double, _ reached: () -> Bool) {
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
