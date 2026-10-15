import XCTest

// The framing row of the clip panel, `clip.framing`: Fit, Fill, Blur and All clips for the selected clip. On
// `two-clips` (the 9:16 canvas) blue is 1920 by 1080 for 3 seconds, so fitted it stands between black bars and
// covers 0.316 of the picture, then red 1080 by 1920 for 4 seconds. At 1 second (`-playhead 600`) blue is from
// x 141 to 321 and red from x 321 to 561. The framing of the selected clip is read from `clip.frameInfo`,
// "<fit|fill> <black|blur> <zoom times 100> <x times 1000>,<y times 1000>", the picture through the probe
// `share(of:in:)` and a build of the player through the count in the value of `editor.picture`. Each test starts
// with `-drafts fresh -seed two-clips -playhead 600` and a tap on blue.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class FramingPanelTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)
    private let controls = ["clip.fit", "clip.fill", "clip.blur", "clip.applyAll"]

    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    /// The seconds from the editor or an edit to its frame in the picture area, as `PictureTests` waits.
    private let expectedFrame = 3.0

    func testTheFourControlsStandInOneRowInEachLanguage() {
        for language in ["en", "ar", "sv"] {
            let app = startFraming(language: language)
            waitUntil("clip.frameInfo reading fit black 100 0,0 in " + language) {
                self.info(app) == "fit black 100 0,0"
            }
            XCTAssertTrue(element(app, "clip.framing").exists, "the container clip.framing in " + language)
            let screen = app.frame
            var frames: [CGRect] = []
            for control in controls {
                let found = element(app, control)
                XCTAssertTrue(found.isHittable, control + " hittable in " + language)
                frames.append(found.frame)
                print("framing: in " + language + " " + control + " at \(found.frame)")
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
            for index in frames.indices.dropFirst() {
                if language == "ar" {
                    XCTAssertGreaterThan(
                        frames[index - 1].minX, frames[index].maxX,
                        controls[index - 1] + " right of " + controls[index] + " in Arabic")
                } else {
                    XCTAssertLessThan(
                        frames[index - 1].maxX, frames[index].minX,
                        controls[index - 1] + " left of " + controls[index] + " in " + language)
                }
            }
            if language != "en" {
                element(app, "clip.fill").tap()
                waitUntil("clip.frameInfo reading fill black 100 0,0 after clip.fill in " + language) {
                    self.info(app) == "fill black 100 0,0"
                }
                let filled = waitForTheShare(in: element(app, "editor.picture"), "blue filling in " + language, above: 0.9)
                XCTAssertGreaterThan(filled, 0.9, "blue filled in " + language)
                screenshot("framing-01-fill-" + language)
            }
            app.terminate()
        }
    }

    func testFillUndoBlurAndAllClips() {
        let app = startFraming()
        let picture = element(app, "editor.picture")

        // Fill: blue covers the picture and the player builds nothing.
        let fitted = waitForTheShare(in: picture, "blue standing between bars", above: 0.2)
        XCTAssertLessThan(fitted, 0.4, "blue fitted")
        let before = builds(picture)
        XCTAssertNotNil(before, "editor.picture has no count of builds")
        mark("framing-01-fill")
        element(app, "clip.fill").tap()
        waitUntil("clip.frameInfo reading fill black 100 0,0 after clip.fill") {
            self.info(app) == "fill black 100 0,0"
        }
        let filled = waitForTheShare(in: picture, "blue filling", above: 0.9)
        print("framing: the share of blue before clip.fill \(fitted) and after it \(filled)")
        XCTAssertGreaterThan(filled, 0.9, "blue filled")
        print("framing: editor.picture before clip.fill \(before ?? -1) and after it \(builds(picture) ?? -1)")
        XCTAssertEqual(builds(picture), before, "the count of builds")
        screenshot("framing-01-fill")

        // The undo brings the bars back.
        element(app, "editor.undo").tap()
        waitUntil("clip.frameInfo reading fit black 100 0,0 after the undo") {
            self.info(app) == "fit black 100 0,0"
        }
        let undone = waitForTheShare(in: picture, "blue between bars again", below: 0.4)
        XCTAssertLessThan(undone, 0.4, "blue fitted after the undo")

        // Blur: the bars carry blurred blue.
        mark("framing-02-blur")
        element(app, "clip.blur").tap()
        waitUntil("clip.frameInfo reading fit blur 100 0,0 after clip.blur") {
            self.info(app) == "fit blur 100 0,0"
        }
        let blurred = waitForTheShare(in: picture, "blue with blurred bars", above: 0.8)
        XCTAssertGreaterThan(blurred, 0.8, "blue with blurred bars")
        screenshot("framing-02-blur")

        // All clips: red takes blue's fit and bars, and one undo takes them back.
        mark("framing-03-all-clips")
        element(app, "clip.applyAll").tap()
        selectRed(app)
        waitUntil("clip.frameInfo reading fit blur 100 0,0 with red selected after clip.applyAll") {
            self.info(app) == "fit blur 100 0,0"
        }
        element(app, "editor.undo").tap()
        selectRed(app)
        waitUntil("clip.frameInfo reading fit black 100 0,0 with red selected after the undo") {
            self.info(app) == "fit black 100 0,0"
        }
    }

    func testFillIsKeptInTheDraft() {
        var app = startFraming()
        element(app, "clip.fill").tap()
        waitUntil("clip.frameInfo reading fill black 100 0,0 after clip.fill") {
            self.info(app) == "fill black 100 0,0"
        }
        app.terminate()

        // The app ended: the reopened draft keeps blue filled.
        app = startApp(seed: nil, drafts: "kept")
        waitUntil("drafts.row.1 on the start screen", expected: expectedStart) {
            self.element(app, "drafts.row.1").exists
        }
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        selectBlue(app)
        waitUntil("clip.frameInfo reading fill black 100 0,0 in the reopened draft") {
            self.info(app) == "fill black 100 0,0"
        }
    }

    /// Starts on `two-clips` at 1 second with fresh drafts, waits for the editor and selects blue.
    private func startFraming(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "two-clips", language: language, playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        selectBlue(app)
        return app
    }

    /// Taps the middle of blue and waits until it is selected and the row shows.
    private func selectBlue(_ app: XCUIApplication) {
        let block = element(app, "editor.clip.1")
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("editor.clip.1 selected and clip.framing after the tap on it") {
            block.isSelected && self.element(app, "clip.framing").exists
        }
    }

    /// Taps red at the normalised offset (0.15, 0.5), as `ReorderTests` taps a block, and waits until it is selected.
    private func selectRed(_ app: XCUIApplication) {
        let block = element(app, "editor.clip.2")
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        waitUntil("editor.clip.2 selected after the tap on it") { block.isSelected }
    }

    private func info(_ app: XCUIApplication) -> String {
        app.staticTexts["clip.frameInfo"].label
    }

    /// The value of `editor.picture` as a number: the count of the items the preview built.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads the share of blue in the picture until it is above or below the number, expected within
    /// `expectedFrame` seconds and given up above three times that. Prints the seconds and answers the last share.
    private func waitForTheShare(
        in picture: XCUIElement, _ what: String, above: Double? = nil, below: Double? = nil
    ) -> Double {
        let started = Date()
        var found = share(of: blue, in: picture)
        var waited = Date().timeIntervalSince(started)
        func reached() -> Bool {
            if let above {
                return found > above
            }
            return found < (below ?? 0)
        }
        while !reached() && waited <= 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: blue, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print("framing: waited \(waited) seconds for \(what), the share of blue \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
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
        print("framing: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
