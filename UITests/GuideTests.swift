import XCTest

// The Instagram guide over the picture, turned on and off by `clip.guide`, the fifth control of the framing row
// `clip.framing`. It shows only on the 9:16 canvas: `editor.guide` over `editor.picture`, its safe rectangle the
// element `editor.guide.safe` at 0.06, 0.14, 0.88 and 0.51 of the picture's width and height (x, y, width, height).
// On `two-clips` at 1 second (`-playhead 600`) blue is from x 141 to 321 on the strip and red from 321 to 561, so the
// strip left of blue is empty. A build of the player is read through the count in the value of `editor.picture`, the
// framing of the selected clip from `clip.frameInfo`. Each test starts with `-drafts fresh` and a tap on blue.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class GuideTests: XCTestCase {
    private let controls = ["clip.fit", "clip.fill", "clip.blur", "clip.applyAll", "clip.guide"]

    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    func testTheFiveControlsInOneRowAndTheGuideInEachLanguage() {
        for language in ["en", "ar", "sv"] {
            let app = startGuide(language: language)
            let screen = app.frame
            var frames: [CGRect] = []
            for control in controls {
                let found = element(app, control)
                XCTAssertTrue(found.isHittable, control + " hittable in " + language)
                frames.append(found.frame)
                print("guide: in " + language + " " + control + " at \(found.frame)")
                XCTAssertGreaterThanOrEqual(found.frame.minX, screen.minX, control + " inside the screen")
                XCTAssertLessThanOrEqual(found.frame.maxX, screen.maxX, control + " inside the screen")
            }
            for first in frames.indices {
                for second in frames.indices where second > first {
                    XCTAssertFalse(
                        frames[first].intersects(frames[second]),
                        controls[first] + " over " + controls[second] + " in " + language)
                    // One row: the two share a stretch of height.
                    XCTAssertLessThan(frames[first].minY, frames[second].maxY, "one row in " + language)
                    XCTAssertLessThan(frames[second].minY, frames[first].maxY, "one row in " + language)
                }
            }

            let picture = element(app, "editor.picture")
            let before = builds(picture)
            XCTAssertNotNil(before, "editor.picture has no count of builds")
            XCTAssertFalse(element(app, "editor.guide").exists, "editor.guide before clip.guide in " + language)
            showTheGuide(app)
            let safe = element(app, "editor.guide.safe").frame
            let area = picture.frame
            print("guide: in " + language + " editor.picture at \(area) and editor.guide.safe at \(safe)")
            XCTAssertEqual(safe.minX - area.minX, 0.06 * area.width, accuracy: 1, "x of the safe area in " + language)
            XCTAssertEqual(safe.minY - area.minY, 0.14 * area.height, accuracy: 1, "y of the safe area in " + language)
            XCTAssertEqual(safe.width, 0.88 * area.width, accuracy: 1, "width of the safe area in " + language)
            XCTAssertEqual(safe.height, 0.51 * area.height, accuracy: 1, "height of the safe area in " + language)
            print("guide: editor.picture before clip.guide \(before ?? -1) and after it \(builds(picture) ?? -1)")
            XCTAssertEqual(builds(picture), before, "the count of builds in " + language)
            screenshot(language == "en" ? "guide-01-shown" : "guide-01-shown-" + language)
            app.terminate()
        }
    }

    func testTheGuideStaysWhenThePanelGoesAndATapTurnsItOff() {
        let app = startGuide()
        showTheGuide(app)

        // The middle of the height at x 40, left of blue.
        element(app, "editor.timelineRegion").coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        waitUntil("no clip.framing after the tap left of blue") { !self.element(app, "clip.framing").exists }
        XCTAssertTrue(element(app, "editor.guide").exists, "editor.guide after the panel went")

        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        waitUntil("editor.clip.2 selected and clip.guide after the tap on it") {
            red.isSelected && self.element(app, "clip.guide").exists
        }
        element(app, "clip.guide").tap()
        waitUntil("no editor.guide after the second tap on clip.guide") { !self.element(app, "editor.guide").exists }
    }

    func testOnTheLandscapeCanvasTheGuideIsDisabled() {
        let app = startApp(seed: "two-clips-wide", playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        selectBlue(app)
        XCTAssertTrue(element(app, "clip.guide").exists, "clip.guide on the landscape canvas")
        XCTAssertFalse(element(app, "clip.guide").isEnabled, "clip.guide enabled on the landscape canvas")
        XCTAssertFalse(element(app, "editor.guide").exists, "editor.guide on the landscape canvas")
    }

    /// The guide takes no touch: with it shown a drag of 60 points upward on the picture still moves blue up.
    func testWithTheGuideShownADragOnThePictureStillMovesBlue() {
        let app = startGuide()
        showTheGuide(app)
        let picture = element(app, "editor.picture")
        let start = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -60)))
        waitUntil("a y below 0 after a drag of 60 points upward with the guide shown") { self.offsetY(app) < 0 }
        print("guide: clip.frameInfo after the drag reads " + app.staticTexts["clip.frameInfo"].label)
        XCTAssertTrue(element(app, "editor.guide").exists, "editor.guide after the drag")
    }

    func testTheGuideIsOffWhenTheDraftOpensAgain() {
        var app = startGuide()
        showTheGuide(app)
        app.terminate()

        app = startApp(seed: nil, drafts: "kept")
        waitUntil("drafts.row.1 on the start screen", expected: expectedStart) {
            self.element(app, "drafts.row.1").exists
        }
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        selectBlue(app)
        XCTAssertFalse(element(app, "editor.guide").exists, "editor.guide in the reopened draft")
        XCTAssertFalse(element(app, "clip.guide").isSelected, "clip.guide selected in the reopened draft")
    }

    /// Starts on `two-clips` at 1 second with fresh drafts, waits for the editor and selects blue.
    private func startGuide(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "two-clips", language: language, playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        selectBlue(app)
        return app
    }

    /// Taps the middle of blue and waits until it is selected and the framing row shows.
    private func selectBlue(_ app: XCUIApplication) {
        let block = element(app, "editor.clip.1")
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("editor.clip.1 selected and clip.framing after the tap on it") {
            block.isSelected && self.element(app, "clip.framing").exists
        }
    }

    /// Taps `clip.guide` and waits until the guide and its safe area are laid out.
    private func showTheGuide(_ app: XCUIApplication) {
        element(app, "clip.guide").tap()
        let safe = element(app, "editor.guide.safe")
        waitUntil("editor.guide and editor.guide.safe with a frame after clip.guide") {
            self.element(app, "editor.guide").exists && safe.exists && safe.frame.width > 0
        }
    }

    /// The y of the offset in `clip.frameInfo`, times 1000. A line with no offset gives 0 and fails the test.
    private func offsetY(_ app: XCUIApplication) -> Int {
        let fields = app.staticTexts["clip.frameInfo"].label.split(separator: " ")
        let parts = fields.count == 4 ? fields[3].split(separator: ",").compactMap { Int($0) } : []
        guard parts.count == 2 else {
            XCTFail("clip.frameInfo has no offset: " + app.staticTexts["clip.frameInfo"].label)
            return 0
        }
        return parts[1]
    }

    /// The value of `editor.picture` as a number: the count of the items the preview built.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
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
        print("guide: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
