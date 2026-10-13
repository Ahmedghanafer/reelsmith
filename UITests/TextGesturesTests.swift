import XCTest

// The gestures on the picture area, on the landscape seeds text-wide (three white lines at 960, 540 for
// the whole video), text-box-wide (the word "BOX" from 600 to 1500 ticks) and two-clips-wide (no text).
// A start on a text seed has its text selected and the panel open. The values of the text are read from
// `editor.textInfo` by the place of a field, counted from 1: field 3 is the size, field 6 the centre as
// "x,y" and field 7 the rotation. The picture is read through the probe `share(of:in:)`. A gesture
// asserts a direction and a limit, never a value between them. A scripted pinch and a scripted twist are
// the two fingers XCTest sends to an element. Before and after each the test prints the field it changes.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/rotate(_:withvelocity:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class TextGesturesTests: XCTestCase {
    private let white = (r: 255, g: 255, b: 255)
    private let blue = (r: 0, g: 0, b: 255)

    /// T: with a text in the picture the share of white is more than this. The clips have no white pixel.
    private let leastWhite = 0.00001
    private let seedText = "1 naskh 64 255,255,255 centre 960,540 0 ... 0+4200 0"

    func testATapOnThePictureSelectsTheNearestText() {
        let app = startGestures(seed: "text-wide", playhead: 600)
        let picture = element(app, "editor.picture")
        tapDone(app)
        XCTAssertEqual(textInfo(app), "none")

        // A corner of the picture, away from the letters in its middle.
        tapACorner(of: picture)
        waitUntil("the text selected after the tap on the picture, the panel on the part look in its row") {
            self.textInfo(app) == self.seedText && self.element(app, "editor.textRegion").exists
                && self.element(app, "text.tab.look").isSelected && self.partsInOneRow(app)
        }
        XCTAssertEqual(textInfo(app), seedText)
        XCTAssertGreaterThan(waitForWhite(in: picture, "after the tap that selects"), leastWhite, "white")
        screenshot("text-gestures-01-selected")
    }

    func testATapWhereNoTextHoldsThePlayheadSelectsNothing() {
        var app = startGestures(seed: "two-clips-wide", playhead: 600)
        tapACorner(of: element(app, "editor.picture"))
        XCTAssertEqual(textInfo(app), "none")

        // The box runs from 600 to 1500 ticks: at 0 there is no text to select.
        app = startGestures(seed: "text-box-wide")
        tapDone(app)
        tapACorner(of: element(app, "editor.picture"))
        XCTAssertEqual(textInfo(app), "none")
        XCTAssertFalse(element(app, "editor.textRegion").exists)

        app = startGestures(seed: "text-box-wide", playhead: 900)
        tapDone(app)
        tapACorner(of: element(app, "editor.picture"))
        waitUntil("the box selected after the tap on the picture at 900 ticks") { self.field(1, app) == "1" }

        // The playhead at the very end of the project still shows the last frame, with its text.
        app = startGestures(seed: "text-wide", playhead: 4200)
        tapDone(app)
        tapACorner(of: element(app, "editor.picture"))
        waitUntil("the text selected after the tap on the picture at the end") { self.field(1, app) == "1" }
    }

    func testADragMovesTheSelectedTextTheWayOfTheFinger() {
        let app = startGestures(seed: "text-wide", playhead: 600)
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForWhite(in: picture, "before the drag"), leastWhite, "white")
        print("text-gestures: the picture is \(picture.frame.width) by \(picture.frame.height) points with the panel open")

        mark("text-gestures-01-drag")
        drag(picture, fromX: 0.15, y: 0.15, byX: 60, y: 30)
        waitUntil("a centre right of 960 and under 540 after the drag to the right and down") {
            self.centre(app).x > 960 && self.centre(app).y > 540
        }
        let first = centre(app)
        print("text-gestures: field 6 after 60 points right and 30 down reads \(field(6, app))")
        XCTAssertGreaterThan(waitForWhite(in: picture, "after the first drag"), leastWhite, "white")

        drag(picture, fromX: 0.85, y: 0.15, byX: -120, y: 0)
        waitUntil("a centre left of the one before after the drag to the left") { self.centre(app).x < first.x }
        print("text-gestures: field 6 after 120 points left reads \(field(6, app))")
        XCTAssertGreaterThan(waitForWhite(in: picture, "after the second drag"), leastWhite, "white")
        screenshot("text-gestures-02-moved")
    }

    func testAMoveStopsWithTheCentreOnTheEdgeOfTheCanvas() {
        let app = startGestures(seed: "text-wide", playhead: 600)
        let picture = element(app, "editor.picture")
        let width = Double(picture.frame.width)
        let height = Double(picture.frame.height)

        for _ in 0..<2 {
            drag(picture, fromX: 0.03, y: 0.15, byX: 0.94 * width, y: 0)
            print("text-gestures: field 6 after a drag from the left edge to the right edge reads \(field(6, app))")
        }
        waitUntil("an x of 1920 after two drags from the left edge to the right edge") {
            self.centre(app).x == 1920
        }
        for _ in 0..<2 {
            drag(picture, fromX: 0.15, y: 0.95, byX: 0, y: -0.9 * height)
            print("text-gestures: field 6 after a drag from the bottom to the top reads \(field(6, app))")
        }
        waitUntil("a y of 0 after two drags from the bottom to the top") { self.centre(app).y == 0 }
        XCTAssertEqual(centre(app).x, 1920)
    }

    func testAPinchSizesTheSelectedTextBetweenTheLimits() {
        let app = startGestures(seed: "text-wide", playhead: 600)
        let picture = element(app, "editor.picture")
        XCTAssertEqual(field(3, app), "64")

        mark("text-gestures-02-pinch")
        pinch(picture, app, outward: true)
        waitUntil("a size above 64 after a pinch outward") { self.number(3, app) > 64 }
        let large = number(3, app)
        pinch(picture, app, outward: false)
        waitUntil("a smaller size after a pinch inward") { self.number(3, app) < large }

        // Each pinch outward is about one and a half times the size, so 400 comes within 6 of them.
        var pinches = 0
        while number(3, app) < 400 && pinches < 14 {
            pinch(picture, app, outward: true)
            pinches += 1
        }
        waitUntil("a size of 400 after \(pinches) pinches outward") { self.number(3, app) == 400 }
        pinch(picture, app, outward: true)
        XCTAssertEqual(field(3, app), "400")

        // Each pinch inward is about two thirds of the size, so 16 comes within 9 of them.
        pinches = 0
        while number(3, app) > 16 && pinches < 20 {
            pinch(picture, app, outward: false)
            pinches += 1
        }
        waitUntil("a size of 16 after \(pinches) pinches inward") { self.number(3, app) == 16 }
        pinch(picture, app, outward: false)
        XCTAssertEqual(field(3, app), "16")
    }

    func testATwistTurnsTheSelectedTextTheWayOfTheFingers() {
        var app = startGestures(seed: "text-wide", playhead: 600)
        var picture = element(app, "editor.picture")

        // Just over one degree: at most 3 from straight comes back to 0.
        twist(picture, app, by: 0.02)
        XCTAssertEqual(field(7, app), "0")

        mark("text-gestures-03-twist")
        twist(picture, app, by: 0.5)
        waitUntil("a rotation above 0 and below 90 after a twist to the right") {
            self.number(7, app) > 0 && self.number(7, app) < 90
        }
        XCTAssertGreaterThan(waitForWhite(in: picture, "after the twist"), leastWhite, "white")
        screenshot("text-gestures-03-turned")

        pinch(picture, app, outward: true)
        waitUntil("a size above 64 after a pinch outward on the turned text") { self.number(3, app) > 64 }
        XCTAssertNotEqual(field(7, app), "0")
        XCTAssertGreaterThan(waitForWhite(in: picture, "larger and turned"), leastWhite, "white")
        screenshot("text-gestures-04-large-turned")

        app = startGestures(seed: "text-wide", playhead: 600)
        picture = element(app, "editor.picture")
        twist(picture, app, by: -0.5)
        waitUntil("a rotation below 0 after a twist to the left") { self.number(7, app) < 0 }
    }

    func testWithNoTextSelectedTheGesturesChangeNothing() {
        var app = startGestures(seed: "text-wide", playhead: 600)
        tapDone(app)
        assertTheGesturesChangeNothing(app)

        app = startGestures(seed: "two-clips-wide", playhead: 600)
        assertTheGesturesChangeNothing(app)
    }

    func testInArabicADragToTheRightStillMovesTheTextToTheRight() {
        let app = startGestures(seed: "text-wide", language: "ar", playhead: 600)
        let picture = element(app, "editor.picture")

        drag(picture, fromX: 0.15, y: 0.15, byX: 60, y: 30)
        waitUntil("a centre right of 960 after the drag to the right in Arabic") { self.centre(app).x > 960 }
        print("text-gestures: field 6 after 60 points right and 30 down in Arabic reads \(field(6, app))")
        XCTAssertGreaterThan(waitForWhite(in: picture, "after the drag in Arabic"), leastWhite, "white")
        screenshot("text-gestures-02-moved-ar")
    }

    func testThePlayButtonStartsAndPausesWithATextSelected() {
        let app = startGestures(seed: "text-wide")
        let play = element(app, "editor.play")
        XCTAssertEqual(field(1, app), "1")

        play.tap()
        waitUntil("the button reading Pause after the tap on play") { play.label == "Pause" }
        // A tap that lands after the end would start the playback again. From "00:06" on no tap is sent
        // and the playback ends by itself inside the wait below.
        let before = timeBeforeTheSlash(app)
        print("text-gestures: the time read before the tap that pauses is \(before)")
        if before < "00:06" {
            play.tap()
        }
        waitUntil("the button reading Play after the pause", expected: 3) { play.label == "Play" }
        XCTAssertEqual(field(1, app), "1")
    }

    /// A drag, a pinch and a twist on the picture with nothing selected: no text gets selected and the
    /// time stands. Nothing follows these gestures that a wait could read, so the lines are read at once.
    private func assertTheGesturesChangeNothing(_ app: XCUIApplication) {
        let picture = element(app, "editor.picture")
        let time = element(app, "editor.time").label
        XCTAssertEqual(textInfo(app), "none")

        drag(picture, fromX: 0.15, y: 0.15, byX: 60, y: 30)
        XCTAssertEqual(textInfo(app), "none", "after a drag")
        picture.pinch(withScale: 1.5, velocity: 1.5)
        XCTAssertEqual(textInfo(app), "none", "after a pinch")
        picture.rotate(0.5, withVelocity: 1)
        XCTAssertEqual(textInfo(app), "none", "after a twist")
        XCTAssertEqual(element(app, "editor.time").label, time)
        XCTAssertFalse(element(app, "editor.textRegion").exists)
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startGestures(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
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

    /// The n-th field of `editor.textInfo`, counted from 1. Empty when the line has no such field.
    private func field(_ place: Int, _ app: XCUIApplication) -> String {
        let fields = textInfo(app).split(separator: " ")
        return fields.count >= place ? String(fields[place - 1]) : ""
    }

    /// A field that is one whole number: the size or the rotation. A field that is none fails the test.
    private func number(_ place: Int, _ app: XCUIApplication) -> Int {
        let read = field(place, app)
        guard let value = Int(read) else {
            XCTFail("field \(place) of editor.textInfo is no whole number: " + read)
            return 0
        }
        return value
    }

    /// Field 6, the centre of the text in canvas pixels. A line with no centre gives -1, -1.
    private func centre(_ app: XCUIApplication) -> (x: Int, y: Int) {
        let parts = field(6, app).split(separator: ",").compactMap { Int($0) }
        return parts.count == 2 ? (x: parts[0], y: parts[1]) : (x: -1, y: -1)
    }

    private func timeBeforeTheSlash(_ app: XCUIApplication) -> String {
        element(app, "editor.time").label.components(separatedBy: " / ").first ?? ""
    }

    /// The upper left corner of the picture: the letters of every seed stand in its middle.
    private func tapACorner(of picture: XCUIElement) {
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12)).tap()
    }

    /// One finger, from a share of the picture, by points of the screen.
    private func drag(_ picture: XCUIElement, fromX: Double, y fromY: Double, byX: Double, y byY: Double) {
        let start = picture.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: fromY))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: byX, dy: byY)))
    }

    /// One scripted pinch, with field 3 printed before and after it.
    private func pinch(_ picture: XCUIElement, _ app: XCUIApplication, outward: Bool) {
        let before = field(3, app)
        if outward {
            picture.pinch(withScale: 1.5, velocity: 1.5)
        } else {
            picture.pinch(withScale: 0.67, velocity: -1)
        }
        print("text-gestures: field 3 before a pinch \(outward ? "outward" : "inward") reads \(before) and after it \(field(3, app))")
    }

    /// One scripted twist in radians, positive to the right, done in half a second, with field 7 printed
    /// before and after it.
    private func twist(_ picture: XCUIElement, _ app: XCUIApplication, by radians: Double) {
        let before = field(7, app)
        picture.rotate(CGFloat(radians), withVelocity: CGFloat(radians * 2))
        print("text-gestures: field 7 before a twist of \(radians) radians reads \(before) and after it \(field(7, app))")
    }

    /// Taps done and waits until the text region is gone and the picture is as wide as its region again.
    private func tapDone(_ app: XCUIApplication) {
        element(app, "text.done").tap()
        waitUntil("the text region gone after the tap on done, the picture as wide as its region", expected: 2) {
            !self.element(app, "editor.textRegion").exists
                && abs(
                    self.element(app, "editor.picture").frame.width
                        - self.element(app, "editor.previewRegion").frame.width) <= 1
        }
    }

    /// True when the three part buttons and done are there with their middles at one height, within 4 points.
    private func partsInOneRow(_ app: XCUIApplication) -> Bool {
        let controls = ["text.tab.type", "text.tab.look", "text.tab.more", "text.done"].map { element(app, $0) }
        guard controls.allSatisfy({ $0.exists }) else {
            return false
        }
        let heights = controls.map { Double($0.frame.midY) }
        return (heights.max() ?? 0) - (heights.min() ?? 0) <= 4
    }

    /// No element says when a frame is drawn, so the share of white is asked again until it is more than
    /// T. Prints the seconds it waited, gives up only above three times the expected 3, and answers the
    /// last share it read.
    private func waitForWhite(in picture: XCUIElement, _ when: String) -> Double {
        let expected: Double = 3
        let started = Date()
        var waited: Double = 0
        var found = share(of: white, in: picture)
        while !(found > leastWhite) && waited <= 3 * expected {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: white, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print(
            "text-gestures: waited \(waited) seconds for a share of white above \(leastWhite) \(when), found \(found), the share of blue is \(share(of: blue, in: picture)), expected \(expected), limit \(3 * expected)"
        )
        return found
    }

    /// Reads until the condition holds, for the effect of a tap or of a gesture. It fails only above three
    /// times the expected seconds: a hosted runner under load can hold the app for seconds.
    @discardableResult
    private func waitUntil(_ what: String, expected: Double = 1, _ reached: () -> Bool) -> Bool {
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
        print("text-gestures: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
