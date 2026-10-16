import XCTest

// A draft written by the Swift encoder that m6 ships, opened by the app. `-draft-fixture <name>` copies the fixture
// `<name>.json` of `Tests/Fixtures/Drafts/swift/` from the debug bundle into `<caches>/TestDrafts/<name>/`, with every
// file of `<caches>/Seeds/` in its Media. So each test first starts the seeds whose files the draft names, with no
// `-drafts`, which writes those files and makes no draft, then empties the test drafts with `-drafts fresh`, then
// starts with `-drafts kept -draft-fixture <name>` and opens the one row. The draft is read through `start.draftsInfo`,
// `editor.seedInfo`, the value of each block, `editor.textInfo`, `editor.soundInfo`, `clip.frameInfo` and the label
// of `editor.exportSettings`. No picture is judged by a pixel.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/launcharguments
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class DraftFixtureTests: XCTestCase {
    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    /// seed-music-wide: the seed music-wide after green added and the text "Peace" typed, an undo history of two
    /// steps, 1080p at 30. One undo takes back the text and leaves the three clips and the music.
    func testTheDraftOfASeedOpensAsWrittenAndOneUndoTakesBackItsLastStep() {
        let app = openFixture("seed-music-wide", seeds: ["three-clips", "music-wide"], info: "1 3+5400+1+1080x30+.")
        waitUntil("3 clips, 4 files in editor.seedInfo") {
            app.staticTexts["editor.seedInfo"].label == "3 clips, 4 files"
        }
        let blocks = ["blue 0+1800 100 v", "red 0+2400 100 v", "green 0+1200 100 v"]
        XCTAssertEqual(values(app, 3), blocks)
        XCTAssertFalse(element(app, "editor.clip.4").exists)
        XCTAssertEqual(soundInfo(app), "100 . 0+5400 100 0 0")
        XCTAssertTrue(element(app, "editor.music").exists)
        assertTheLabel(app, holds: "1080p", "30 fps")

        // The text, selected by a tap near the start of its bar, which runs from the playhead past the screen.
        let bar = element(app, "editor.text.1")
        XCTAssertEqual(bar.value as? String ?? "", "Peace")
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        waitUntil("text 1 in editor.textInfo after the tap on its bar") { self.textInfo(app).hasPrefix("1 ") }
        XCTAssertTrue(
            textInfo(app).hasPrefix("1 naskh 64 255,255,255 centre 960,540 0 ... 0+5400 "), textInfo(app))
        let undo = element(app, "editor.undo")
        XCTAssertTrue(undo.isEnabled, "the history did not come with the draft")
        screenshot("draft-fixture-02-opened")

        // The last step of the history was the text.
        undo.tap()
        waitUntil("no text after the tap on editor.undo") { self.textInfo(app) == "none" && !bar.exists }
        XCTAssertEqual(values(app, 3), blocks)
        XCTAssertEqual(soundInfo(app), "100 . 0+5400 100 0 0")
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "3 clips, 4 files")
        screenshot("draft-fixture-03-undone")
    }

    /// photo-framing-text-4k: photo-wide with blue framed, a text with every member set, 4K at 60, no history.
    func testTheDraftWithAPhotoAFramingAndATextOpensAsWritten() {
        let app = openFixture("photo-framing-text-4k", seeds: ["photo-wide"], info: "1 3+6000+1+2160x60+.")
        waitUntil("3 clips, 3 files in editor.seedInfo") {
            app.staticTexts["editor.seedInfo"].label == "3 clips, 3 files"
        }
        XCTAssertEqual(values(app, 3), ["blue 0+1800 100 v", "magenta 0+1800 100 p", "red 0+2400 100 v"])
        XCTAssertEqual(soundInfo(app), "100 . none")
        assertTheLabel(app, holds: "4K", "60 fps")
        XCTAssertFalse(element(app, "editor.undo").isEnabled, "a draft with no history")

        // The framing of blue: fill, blurred bars, a zoom of 1.5 and an offset of 0.125 and -0.0625.
        let blue = element(app, "editor.clip.1")
        blue.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("editor.clip.1 selected with clip.frameInfo after the tap on it") {
            blue.isSelected && app.staticTexts["clip.frameInfo"].exists
        }
        let frame = app.staticTexts["clip.frameInfo"].label
        print("draft-fixture: clip.frameInfo reads " + frame)
        XCTAssertTrue(frame.hasPrefix("fill blur 150 125,-6"), frame)

        // The text, from 600 ticks for 1200, on the screen from x 261 to 381.
        let bar = element(app, "editor.text.1")
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("text 1 in editor.textInfo after the tap on its bar") { self.textInfo(app).hasPrefix("1 ") }
        let fields = textInfo(app).split(separator: " ").map(String.init)
        print("draft-fixture: editor.textInfo reads " + textInfo(app))
        XCTAssertEqual(fields.count, 10, textInfo(app))
        if fields.count == 10 {
            XCTAssertEqual(fields[1], "naskh-bold")
            XCTAssertEqual(fields[2], "64")
            XCTAssertEqual(fields[3], "255,214,10")
            XCTAssertEqual(fields[4], "right")
            XCTAssertEqual(fields[7], "osb")
            XCTAssertEqual(fields[8], "600+1200")
            XCTAssertEqual(fields[9], "25")
        }
        screenshot("draft-fixture-04-photo")
    }

    /// Starts each seed with no `-drafts` and waits for its editor, so its files are in `<caches>/Seeds/`, empties the
    /// test drafts, then starts with the fixture, reads the line of the drafts and opens the one row.
    private func openFixture(_ name: String, seeds: [String], info: String) -> XCUIApplication {
        for seed in seeds {
            let seeded = startApp(seed: seed)
            waitForTheEditor(seeded)
            seeded.terminate()
        }
        let fresh = startApp(seed: nil, drafts: "fresh")
        XCTAssertEqual(draftsInfo(fresh), "0")
        fresh.terminate()

        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en", "-drafts", "kept", "-draft-fixture", name,
        ]
        app.launch()
        XCTAssertEqual(draftsInfo(app), info)
        screenshot("draft-fixture-01-list")
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        return app
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: expectedStart) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("draft-fixture: start.draftsInfo reads " + label)
        return label
    }

    private func assertTheLabel(_ app: XCUIApplication, holds size: String, _ rate: String) {
        let label = element(app, "editor.exportSettings").label
        print("draft-fixture: editor.exportSettings reads " + label)
        XCTAssertTrue(label.contains(size), label)
        XCTAssertTrue(label.contains(rate), label)
    }

    private func values(_ app: XCUIApplication, _ count: Int) -> [String] {
        (1...count).map { element(app, "editor.clip." + String($0)).value as? String ?? "" }
    }

    private func textInfo(_ app: XCUIApplication) -> String {
        let line = app.staticTexts["editor.textInfo"]
        return line.exists ? line.label : ""
    }

    private func soundInfo(_ app: XCUIApplication) -> String {
        let line = app.staticTexts["editor.soundInfo"]
        return line.exists ? line.label : ""
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
        print("draft-fixture: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
