import XCTest

// The frames along the blocks. On `two-clips-wide` blue is 3 seconds and red 4, at 60 points a second when the
// editor opens, so the blocks are 180 and 240 points wide and hold 4 and 5 tiles of 56 points. The tiles of a
// block are the element `editor.frames.<n>` with the value "<tiles> <drawn> <made>", made being the media whose
// frames came. A clip is still read through the value of its block `editor.clip.<n>`, its label, which lies on
// top of the tiles. Every test starts with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xctest/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class BlockFramesTests: XCTestCase {
    /// The seconds for the frames of the blocks to come after the editor shows: made once for each media, from
    /// the files in the draft. The criterion's 10 seconds are three times it.
    private let expectedFrames = 10.0 / 3

    /// The seconds from the tap on the right of the picker's bar to the clips in the editor.
    private let expectedCopy = 20.0

    func testEachBlockShowsTheFramesOfItsClip() {
        // At 3 seconds the end of blue is in the middle, so both blocks are on the screen.
        let app = startApp(seed: "two-clips-wide", playhead: 1800, drafts: "fresh")
        waitForTheEditor(app)
        mark("frames-01-strip")
        waitForTheFrames(app, "4 4 2", "5 5 2")
        let blue = share(of: (r: 0, g: 0, b: 255), in: element(app, "editor.clip.1"))
        let red = share(of: (r: 255, g: 0, b: 0), in: element(app, "editor.clip.2"))
        print("frames: the blue share of editor.clip.1 is \(blue), the red share of editor.clip.2 is \(red)")
        XCTAssertGreaterThan(blue, 0.5)
        XCTAssertGreaterThan(red, 0.5)
        XCTAssertEqual(value(app, "editor.clip.1"), "blue 0+1800 100 v")
        XCTAssertEqual(value(app, "editor.clip.2"), "red 0+2400 100 v")
        screenshot("frames-01-strip")
    }

    func testInArabicAndSwedishTheFramesRunLeftToRight() {
        for language in ["ar", "sv"] {
            let app = startApp(seed: "two-clips-wide", language: language, playhead: 1800, drafts: "fresh")
            waitForTheEditor(app)
            waitForTheFrames(app, "4 4 2", "5 5 2")
            let blue = element(app, "editor.clip.1").frame
            let red = element(app, "editor.clip.2").frame
            XCTAssertLessThan(blue.minX, red.minX, language)
            XCTAssertEqual(blue.maxX, red.minX, accuracy: 1, language)
            XCTAssertEqual(element(app, "editor.frames.1").frame.minX, blue.minX, accuracy: 1, language)
            XCTAssertEqual(element(app, "editor.frames.2").frame.minX, red.minX, accuracy: 1, language)
            screenshot("frames-01-strip-" + language)
            app.terminate()
        }
    }

    func testAPinchGivesTheTilesOfTheNewWidthAndMakesNothingNew() {
        let app = startApp(seed: "two-clips-wide", drafts: "fresh")
        waitForTheEditor(app)
        waitForTheFrames(app, "4 4 2", "5 5 2")
        let blue = element(app, "editor.clip.1")
        mark("frames-02-pinch")
        element(app, "editor.timelineRegion").pinch(withScale: 2, velocity: 1)
        waitUntil("editor.clip.1 wider than 270 after a pinch with scale 2", expected: 1) { blue.frame.width > 270 }
        var wanted = ""
        waitUntil("editor.frames.1 with a tile for every 56 points of editor.clip.1, made 2", expected: 1) {
            let tiles = Int((Double(blue.frame.width) / 56).rounded(.up))
            wanted = String(tiles) + " " + String(tiles) + " 2"
            return self.value(app, "editor.frames.1") == wanted
        }
        print("frames: editor.clip.1 is \(blue.frame.width) points wide after the pinch, editor.frames.1 reads "
            + value(app, "editor.frames.1") + ", wanted " + wanted)
        screenshot("frames-02-pinched")
    }

    func testAnAddedClipShowsItsFrames() {
        let app = startApp(seed: "two-clips-wide", drafts: "fresh")
        waitForTheEditor(app)
        waitForTheFrames(app, "4 4 2", "5 5 2")
        element(app, "editor.addClips").tap()
        // The cell 1 from the end is blue, copied in as a media of its own.
        let stopped = chooseInThePhotoPicker(app, fromTheEnd: [1], confirms: true, picture: nil, photos: true)
        XCTAssertNil(stopped, stopped ?? "")
        let added = element(app, "editor.clip.3")
        waitUntil("editor.clip.3 after the picker", expected: expectedCopy) { added.exists }
        print("frames: editor.clip.3 reads " + value(app, "editor.clip.3"))
        waitUntil("editor.frames.3 with every tile drawn, made 3", expected: expectedFrames) {
            let fields = self.value(app, "editor.frames.3").split(separator: " ")
            return fields.count == 3 && fields[0] == fields[1] && fields[2] == "3" && fields[0] != "0"
        }
        print("frames: editor.frames.3 reads " + value(app, "editor.frames.3"))
        screenshot("frames-03-added")
    }

    /// Waits until the tiles of the two blocks read the values, expected within `expectedFrames`.
    private func waitForTheFrames(_ app: XCUIApplication, _ first: String, _ second: String) {
        waitUntil("editor.frames.1 reading " + first + " and editor.frames.2 " + second, expected: expectedFrames) {
            self.value(app, "editor.frames.1") == first && self.value(app, "editor.frames.2") == second
        }
        print("frames: editor.frames.1 reads " + value(app, "editor.frames.1") + ", editor.frames.2 reads "
            + value(app, "editor.frames.2"))
    }

    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        element(app, identifier).value as? String ?? ""
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds.
    private func waitUntil(_ what: String, expected: Double, _ reached: () -> Bool) {
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
        print("frames: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
