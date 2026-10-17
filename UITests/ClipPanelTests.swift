import XCTest

// The clip panel, `editor.clipRegion`, shown while a clip is selected. On `two-clips-wide` blue is 3 seconds and
// red 4, at 60 points a second on a screen 402 points wide with the playhead at x 201. On `photo-wide` the photo
// magenta stands between blue and red. A clip is read by the value of its block, "<media> <start>+<duration>
// <volume times 100> <v or p>". The sound of the project is read from `editor.soundInfo`, whose first field is the
// volume of all clips times 100 and the second "." while not muted. A draft is reopened through `drafts.row.1`.
// Every test starts its first launch with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class ClipPanelTests: XCTestCase {
    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    /// The most moves toward the lower end the test makes before the volume of the clip must read 0.
    private let mostMoves = 5

    func testATapOnABlockShowsThePanelBetweenTheToolsAndTheExport() {
        // At 1 second blue is from x 141 to 321 and red begins at x 321.
        var app = startApp(seed: "two-clips-wide", playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertFalse(element(app, "editor.clipRegion").exists)
        select(app, "editor.clip.1")
        assertThePanel(app)
        XCTAssertTrue(element(app, "clip.cutBefore").isEnabled)
        XCTAssertTrue(element(app, "clip.cutAfter").isEnabled)
        screenshot("clip-panel-01-selected")
        app.terminate()

        // In Arabic the panel mirrors and the strip does not. In Swedish the same panel.
        for language in ["ar", "sv"] {
            app = startApp(seed: "two-clips-wide", language: language, playhead: 600, drafts: "fresh")
            waitForTheEditor(app)
            select(app, "editor.clip.1")
            assertThePanel(app)
            let before = element(app, "clip.cutBefore").frame
            let after = element(app, "clip.cutAfter").frame
            print("clip-panel: in " + language + " clip.cutBefore at \(before), clip.cutAfter at \(after)")
            if language == "ar" {
                XCTAssertGreaterThan(before.minX, after.maxX, "Delete before right of Delete after in Arabic")
            } else {
                XCTAssertLessThan(before.maxX, after.minX, "Delete before left of Delete after")
            }
            XCTAssertLessThan(
                element(app, "editor.clip.1").frame.minX, element(app, "editor.clip.2").frame.minX,
                "blue left of red in " + language)
            screenshot("clip-panel-01-selected-" + language)
            app.terminate()
        }
    }

    func testDeleteBeforeCutsBlueAtThePlayheadAndUndoBringsItBack() {
        let app = startApp(seed: "two-clips-wide", playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.1")
        mark("clip-panel-02-cut-before")
        element(app, "clip.cutBefore").tap()
        waitUntil("editor.clip.1 reading blue 600+1200 100 v after Delete before") {
            self.value(app, "editor.clip.1") == "blue 600+1200 100 v"
        }
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:06")
        XCTAssertTrue(element(app, "editor.clipRegion").exists)
        screenshot("clip-panel-02-cut-before")

        element(app, "editor.undo").tap()
        waitUntil("editor.clip.1 reading blue 0+1800 100 v after the undo") {
            self.value(app, "editor.clip.1") == "blue 0+1800 100 v"
        }
    }

    func testDeleteAfterCutsBlueAtThePlayhead() {
        // At 2 seconds blue is from x 81 to 261.
        let app = startApp(seed: "two-clips-wide", playhead: 1200, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.1")
        element(app, "clip.cutAfter").tap()
        waitUntil("editor.clip.1 reading blue 0+1200 100 v after Delete after") {
            self.value(app, "editor.clip.1") == "blue 0+1200 100 v"
        }
        let time = element(app, "editor.time").label
        print("clip-panel: editor.time after Delete after reads " + time)
        XCTAssertTrue(time.hasPrefix("00:02"), time)
    }

    func testAtTheStartOfTheClipBothCutsAreDisabled() {
        // At 0 seconds blue is from x 201 to 381.
        let app = startApp(seed: "two-clips-wide", playhead: 0, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.1")
        assertThePanel(app)
        XCTAssertFalse(element(app, "clip.cutBefore").isEnabled)
        XCTAssertFalse(element(app, "clip.cutAfter").isEnabled)
    }

    /// A scripted move does not promise the end of a slider, so the moves to the lowest are repeated until the
    /// value of red ends " 0 v".
    func testTheVolumeOfRedAtItsLowestIsKeptInTheDraft() {
        // At 4 seconds red is from x 141 to 381.
        var app = startApp(seed: "two-clips-wide", playhead: 2400, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.2")
        let slider = element(app, "clip.volume")
        waitUntil("the slider clip.volume") { slider.exists }
        mark("clip-panel-03-volume")
        var moves = 0
        while !value(app, "editor.clip.2").hasSuffix(" 0 v") && moves < mostMoves {
            let before = value(app, "editor.clip.2")
            slide(slider, to: 0)
            moves += 1
            // A move that lands on the step it left changes nothing, so this wait does not fail: the last
            // assert on " 0 v" decides.
            waitUntil(
                "a value of editor.clip.2 other than " + before + " after move \(moves) to the lowest", failing: false
            ) {
                self.value(app, "editor.clip.2") != before
            }
            print("clip-panel: after move \(moves) editor.clip.2 reads " + value(app, "editor.clip.2"))
        }
        XCTAssertTrue(value(app, "editor.clip.2").hasSuffix(" 0 v"), value(app, "editor.clip.2"))
        XCTAssertTrue(value(app, "editor.clip.1").hasSuffix(" 100 v"), value(app, "editor.clip.1"))
        let sound = app.staticTexts["editor.soundInfo"].label
        print("clip-panel: editor.soundInfo reads " + sound)
        XCTAssertTrue(sound.hasPrefix("100 ."), sound)
        screenshot("clip-panel-03-volume")

        // The app ended: the reopened draft keeps the volume of red.
        app.terminate()
        app = startApp(seed: nil, drafts: "kept")
        waitUntil("drafts.row.1 on the start screen", expected: expectedStart) {
            self.element(app, "drafts.row.1").exists
        }
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        waitUntil("editor.clip.2 ending 0 v in the reopened draft") {
            self.value(app, "editor.clip.2").hasSuffix(" 0 v")
        }
    }

    func testAPhotoShowsTheTwoCutsAndNoVolume() {
        // At 4.5 seconds the photo is from x 111 to 291.
        let app = startApp(seed: "photo-wide", playhead: 2700, drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertTrue(value(app, "editor.clip.2").hasSuffix(" p"), value(app, "editor.clip.2"))
        select(app, "editor.clip.2")
        assertThePanel(app, withVolume: false)
        screenshot("clip-panel-04-photo")
    }

    func testATapOnTheEmptyStripRemovesThePanel() {
        let app = startApp(seed: "two-clips-wide", playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.1")
        assertThePanel(app)
        // The middle of the height at x 40, left of the first block.
        element(app, "editor.timelineRegion").coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        waitUntil("no editor.clipRegion after the tap left of the first block") {
            !self.element(app, "editor.clipRegion").exists
        }
        XCTAssertFalse(element(app, "editor.clip.1").isSelected)
    }

    func testNoPanelWithATextSelectedOrWithTheSoundPanelOpen() {
        var app = startApp(seed: "text-wide", drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertTrue(element(app, "editor.textRegion").exists)
        XCTAssertFalse(element(app, "editor.clipRegion").exists)
        app.terminate()

        app = startApp(seed: "music-wide", drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertTrue(element(app, "editor.soundRegion").exists)
        XCTAssertFalse(element(app, "editor.clipRegion").exists)
    }

    /// Taps the middle of the block and waits until it is selected and the panel shows.
    private func select(_ app: XCUIApplication, _ block: String) {
        let clip = element(app, block)
        clip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil(block + " selected and editor.clipRegion after the tap on it") {
            clip.isSelected && self.element(app, "editor.clipRegion").exists
        }
    }

    /// The region stands between the tools and the export and holds the two cuts and, unless told otherwise, the
    /// slider of the volume.
    private func assertThePanel(_ app: XCUIApplication, withVolume: Bool = true) {
        let region = element(app, "editor.clipRegion").frame
        let tools = element(app, "editor.toolsRegion").frame
        let export = element(app, "editor.exportRegion").frame
        print("clip-panel: editor.toolsRegion at \(tools), editor.clipRegion at \(region), editor.exportRegion at \(export)")
        XCTAssertGreaterThanOrEqual(region.minY, tools.maxY - 1, "the panel under the tools")
        XCTAssertLessThanOrEqual(region.maxY, export.minY + 1, "the panel above the export")
        XCTAssertTrue(element(app, "clip.cutBefore").exists)
        XCTAssertTrue(element(app, "clip.cutAfter").exists)
        XCTAssertEqual(element(app, "clip.volume").exists, withVolume)
    }

    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        element(app, identifier).value as? String ?? ""
    }

    /// A Flutter slider reports as another kind and does not take adjust: a press at its middle dragged to the
    /// place moves it, as a finger does.
    private func slide(_ slider: XCUIElement, to place: CGFloat) {
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: place, dy: 0.5)))
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds. With `failing` false it only waits.
    private func waitUntil(_ what: String, expected: Double = 1, failing: Bool = true, _ reached: () -> Bool) {
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
        print("clip-panel: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if failing {
            XCTAssertTrue(holds, what)
        }
    }
}
