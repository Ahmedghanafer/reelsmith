import XCTest

// Punch in on the picture: with a clip selected and the playhead inside it, a pinch on `editor.picture` zooms that
// clip and a one finger drag moves it, each gesture one step of undo. On `two-clips` (the 9:16 canvas) blue is 1920
// by 1080 for 3 seconds, so fitted it stands between black bars and covers 0.316 of the picture, then red 1080 by
// 1920 for 4 seconds. At 1 second (`-playhead 600`) blue is from x 141 to 321 on the strip, at 4 seconds from x -39
// to 141. The framing of the selected clip is read from `clip.frameInfo`, "<fit|fill> <black|blur> <zoom times
// 100> <x times 1000>,<y times 1000>", the picture through the probe `share(of:in:)` and a build of the player
// through the count in the value of `editor.picture`. A scripted pinch reaches about the scale asked, never an
// exact value, so a test reads a direction and a limit and prints the info. Each test starts with `-drafts fresh
// -seed two-clips` and a tap on blue. That the picture grows under the fingers is read by the QA pass in the
// recording from the mark `punch-01-pinch`.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class PunchInTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)
    private let standard = "fit black 100 0,0"

    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    /// The seconds from an edit to its frame in the picture area, as `PictureTests` waits.
    private let expectedFrame = 3.0

    func testAPinchZoomsBlueADragMovesItAndEachIsOneUndoStep() {
        let app = startPunchIn()
        let picture = element(app, "editor.picture")
        let before = waitForTheShare(in: picture, "blue standing between bars", above: 0.2)
        XCTAssertLessThan(before, 0.4, "blue fitted")
        let built = builds(picture)
        XCTAssertNotNil(built, "editor.picture has no count of builds")

        mark("punch-01-pinch")
        pinch(picture, app, scale: 2)
        waitUntil("a zoom above 150 after a pinch with scale 2") { self.zoom(app) > 150 }
        let zoomed = waitForTheShare(in: picture, "blue zoomed", above: before + 0.1)
        print("punch: the share of blue before the pinch \(before) and after it \(zoomed)")
        XCTAssertGreaterThan(zoomed, before, "blue zoomed")
        print("punch: editor.picture before the pinch \(built ?? -1) and after it \(builds(picture) ?? -1)")
        XCTAssertEqual(builds(picture), built, "the count of builds")
        screenshot("punch-01-zoomed")
        let zoomedInfo = info(app)

        // Upward: the picture moves up, so its centre is above the canvas centre.
        mark("punch-02-drag")
        let start = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -60)))
        waitUntil("a y below 0 after a drag of 60 points upward") { self.offset(app).y < 0 }
        print("punch: clip.frameInfo after the drag reads " + info(app))
        XCTAssertGreaterThan(zoom(app), 150, "the zoom after the drag")

        let undo = element(app, "editor.undo")
        undo.tap()
        waitUntil("clip.frameInfo reading " + zoomedInfo + " after one undo") { self.info(app) == zoomedInfo }
        XCTAssertEqual(offset(app).y, 0)
        undo.tap()
        waitUntil("clip.frameInfo reading " + standard + " after a second undo") { self.info(app) == self.standard }
        XCTAssertFalse(undo.isEnabled, "editor.undo after the two undos")
    }

    func testAPinchInwardOnTheStandardFramingChangesNothing() {
        let app = startPunchIn()
        pinch(element(app, "editor.picture"), app, scale: 0.3)
        // Nothing follows a pinch that changes nothing, so the line is read at once.
        XCTAssertEqual(info(app), standard)
        XCTAssertFalse(element(app, "editor.undo").isEnabled, "editor.undo after the pinch")
    }

    func testAPinchWithThePlayheadInsideRedChangesNoClip() {
        let app = startPunchIn(playhead: 2400, blueAt: 0.85)
        pinch(element(app, "editor.picture"), app, scale: 2)
        // Nothing follows a pinch that changes nothing, so the lines are read at once.
        XCTAssertEqual(info(app), standard, "blue")
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("editor.clip.2 selected after the tap on it") { red.isSelected }
        print("punch: clip.frameInfo with red selected reads " + info(app))
        XCTAssertEqual(info(app), standard, "red")
    }

    func testTheZoomIsKeptInTheDraft() {
        var app = startPunchIn()
        pinch(element(app, "editor.picture"), app, scale: 2)
        waitUntil("a zoom above 150 after a pinch with scale 2") { self.zoom(app) > 150 }
        let zoomed = info(app)
        print("punch: clip.frameInfo before the relaunch reads " + zoomed)
        app.terminate()

        // The app ended: the reopened draft keeps blue zoomed.
        app = startApp(seed: nil, drafts: "kept")
        waitUntil("drafts.row.1 on the start screen", expected: expectedStart) {
            self.element(app, "drafts.row.1").exists
        }
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        selectBlue(app)
        waitUntil("clip.frameInfo reading " + zoomed + " in the reopened draft") { self.info(app) == zoomed }
    }

    func testAPinchInArabicAndInSwedish() {
        for language in ["ar", "sv"] {
            let app = startPunchIn(language: language)
            let picture = element(app, "editor.picture")
            let before = waitForTheShare(in: picture, "blue standing between bars in " + language, above: 0.2)
            pinch(picture, app, scale: 2)
            waitUntil("a zoom above 150 after a pinch with scale 2 in " + language) { self.zoom(app) > 150 }
            let zoomed = waitForTheShare(in: picture, "blue zoomed in " + language, above: before + 0.1)
            XCTAssertGreaterThan(zoomed, before, "blue zoomed in " + language)
            screenshot("punch-01-zoomed-" + language)
            app.terminate()
        }
    }

    /// A level of blue changed first, then the pinch: the picture shows the zoom and the player builds nothing.
    func testAPinchAfterALevelShowsTheZoom() {
        let app = startPunchIn()
        let picture = element(app, "editor.picture")
        let before = waitForTheShare(in: picture, "blue standing between bars", above: 0.2)
        let built = builds(picture)
        XCTAssertNotNil(built, "editor.picture has no count of builds")
        let slider = app.sliders["clip.volume"]
        waitUntil("the slider clip.volume") { slider.exists }
        slider.adjust(toNormalizedSliderPosition: 0)
        waitUntil("editor.clip.1 ending other than 100 v after the move of clip.volume") {
            !self.value(app, "editor.clip.1").hasSuffix(" 100 v")
        }
        print("punch: after the move of clip.volume editor.clip.1 reads " + value(app, "editor.clip.1"))

        pinch(picture, app, scale: 2)
        waitUntil("a zoom above 150 after a pinch with scale 2") { self.zoom(app) > 150 }
        let zoomed = waitForTheShare(in: picture, "blue zoomed after the level", above: before + 0.1)
        XCTAssertGreaterThan(zoomed, before, "blue zoomed after the level")
        print("punch: editor.picture before the level \(built ?? -1) and after the pinch \(builds(picture) ?? -1)")
        XCTAssertEqual(builds(picture), built, "the count of builds")
    }

    /// Starts on `two-clips` at the playhead with fresh drafts, waits for the editor and selects blue.
    private func startPunchIn(language: String = "en", playhead: Int = 600, blueAt share: CGFloat = 0.5)
        -> XCUIApplication
    {
        let app = startApp(seed: "two-clips", language: language, playhead: playhead, drafts: "fresh")
        waitForTheEditor(app)
        selectBlue(app, at: share)
        return app
    }

    /// Taps blue at the share of its width and waits until it is selected and its info reads.
    private func selectBlue(_ app: XCUIApplication, at share: CGFloat = 0.5) {
        let block = element(app, "editor.clip.1")
        block.coordinate(withNormalizedOffset: CGVector(dx: share, dy: 0.5)).tap()
        waitUntil("editor.clip.1 selected and clip.frameInfo after the tap on it") {
            block.isSelected && app.staticTexts["clip.frameInfo"].exists
        }
    }

    /// One scripted pinch in a second, with the info printed before and after it.
    private func pinch(_ picture: XCUIElement, _ app: XCUIApplication, scale: CGFloat) {
        let before = info(app)
        picture.pinch(withScale: scale, velocity: scale > 1 ? 1 : -1)
        print("punch: clip.frameInfo before a pinch with scale \(scale) reads \(before) and after it \(info(app))")
    }

    private func info(_ app: XCUIApplication) -> String {
        app.staticTexts["clip.frameInfo"].label
    }

    /// Field 3 of the info, the zoom times 100. A field that is no whole number fails the test.
    private func zoom(_ app: XCUIApplication) -> Int {
        let fields = info(app).split(separator: " ")
        guard fields.count == 4, let zoom = Int(fields[2]) else {
            XCTFail("clip.frameInfo has no zoom: " + info(app))
            return 0
        }
        return zoom
    }

    /// Field 4 of the info, the offset times 1000 as "x,y". A line with no offset gives 0, 0 and fails the test.
    private func offset(_ app: XCUIApplication) -> (x: Int, y: Int) {
        let fields = info(app).split(separator: " ")
        let parts = fields.count == 4 ? fields[3].split(separator: ",").compactMap { Int($0) } : []
        guard parts.count == 2 else {
            XCTFail("clip.frameInfo has no offset: " + info(app))
            return (x: 0, y: 0)
        }
        return (x: parts[0], y: parts[1])
    }

    /// The value of `editor.picture` as a number: the count of the items the preview built.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        element(app, identifier).value as? String ?? ""
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads the share of blue in the picture until it is above the number, expected within `expectedFrame` seconds
    /// and given up above three times that. Prints the seconds and answers the last share.
    private func waitForTheShare(in picture: XCUIElement, _ what: String, above: Double) -> Double {
        let started = Date()
        var found = share(of: blue, in: picture)
        var waited = Date().timeIntervalSince(started)
        while !(found > above) && waited <= 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: blue, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print("punch: waited \(waited) seconds for \(what), the share of blue \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
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
        print("punch: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
