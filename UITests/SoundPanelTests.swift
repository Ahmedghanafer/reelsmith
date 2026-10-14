import XCTest

// The sound button, the sound region and the sound panel, on the seeds music-wide (the clips of two-clips-wide,
// blue 3 seconds and red 4 on the landscape canvas, under the long test tone, the panel open at the start),
// two-clips-wide, text-wide and empty. The sound of the project is read from `editor.soundInfo` and never by a
// word. The parts of the panel are empty slots here, so nothing shows under the row of its part buttons. The
// picture is read through the probe `share(of:in:)`. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementquery/allelementsboundbyindex
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class SoundPanelTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// B: on music-wide at one second the blue clip fills the picture area, so the share of blue is more than
    /// this. A picture that was not built is black.
    private let blueOfTheClip = 0.9

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    private let tabs = ["sound.tab.music", "sound.tab.levels", "sound.tab.clips"]
    private let tools = ["editor.split", "editor.delete", "editor.addText", "editor.sound"]
    private let withMusic = "100 . 0+4200 100 0 0"

    func testAStartOnMusicWideHasThePanelOpenOnThePartMusic() {
        let app = startSound(seed: "music-wide")
        waitForThePanel(app, "the sound region at the start on music-wide, every button in its row")

        // The region lies between the tools and the export.
        let region = element(app, "editor.soundRegion")
        XCTAssertGreaterThanOrEqual(region.frame.minY, element(app, "editor.toolsRegion").frame.maxY - 1)
        XCTAssertLessThanOrEqual(region.frame.maxY, element(app, "editor.exportRegion").frame.minY + 1)
        // One row from leading to trailing, with done at its trailing end, all inside the region.
        let buttons = (tabs + ["sound.done"]).map { region.descendants(matching: .any)[$0] }
        for index in 0..<buttons.count {
            XCTAssertTrue(buttons[index].exists, index < 3 ? tabs[index] : "sound.done")
        }
        XCTAssertLessThan(buttons[0].frame.minX, buttons[1].frame.minX)
        XCTAssertLessThan(buttons[1].frame.minX, buttons[2].frame.minX)
        XCTAssertGreaterThan(buttons[3].frame.minX, buttons[2].frame.maxX)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])

        // The sound button after the text button, the trailing side, and no text region.
        XCTAssertGreaterThan(element(app, "editor.sound").frame.minX, element(app, "editor.addText").frame.minX)
        XCTAssertFalse(element(app, "editor.textRegion").exists)
        XCTAssertEqual(soundInfo(app), withMusic)
        // The seed start wrote the tone file beside the two clips.
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "2 clips, 3 files")
        assertTheToolsRowFits(app, "en")
        screenshot("sound-panel-01-music")
    }

    func testOnMusicWideThePictureIsBuilt() {
        let app = startSound(seed: "music-wide", playhead: 600)
        waitForThePanel(app, "the sound region at the start on music-wide with the playhead at one second")
        let picture = element(app, "editor.picture")
        XCTAssertTrue(picture.exists)

        // Before the mix reads the music this shows only that the preview still builds. Once it does, it shows
        // that the item was built with the tone file found: a file that is missing leaves the picture black.
        let found = waitForTheShare(of: blue, "blue", in: picture, moreThan: blueOfTheClip)
        print("sound-panel: on music-wide at 600 ticks the share of blue is \(found), B \(blueOfTheClip)")
        XCTAssertGreaterThan(found, blueOfTheClip, "blue")
        XCTAssertEqual(soundInfo(app), withMusic)
    }

    func testEachPartButtonSelectsItsPartAndNothingShowsUnderTheRow() {
        let app = startSound(seed: "music-wide")
        waitForThePanel(app, "the sound region at the start on music-wide")

        for tab in [tabs[1], tabs[2], tabs[0]] {
            element(app, tab).tap()
            waitUntil(tab + " alone selected after the tap on it, every button in its row") {
                selectedTabs(app) == [tab] && inOneRow(app, tabs + ["sound.done"])
            }
            XCTAssertEqual(selectedTabs(app), [tab])
            assertNothingUnderTheRow(app, tab)
            XCTAssertEqual(soundInfo(app), withMusic, tab)
        }
    }

    func testDoneAndATapOnABlockCloseThePanel() {
        // At 4 seconds the middles of both blocks are on the screen.
        let app = startSound(seed: "music-wide", playhead: 2400)
        let region = element(app, "editor.soundRegion")
        let delete = element(app, "editor.delete")
        waitForThePanel(app, "the sound region at the start on music-wide with the playhead at 4 seconds")
        element(app, "sound.tab.levels").tap()
        waitUntil("sound.tab.levels selected after the tap on it") { selectedTabs(app) == ["sound.tab.levels"] }

        element(app, "sound.done").tap()
        waitUntil("the sound region gone after the tap on done") { !region.exists }
        XCTAssertEqual(soundInfo(app), withMusic)

        // The panel is made anew, on the part music.
        openSound(app)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])
        XCTAssertFalse(delete.isEnabled)

        let block = element(app, "editor.clip.1")
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the sound region gone and the block selected after the tap on it") {
            !region.exists && block.isSelected
        }
        XCTAssertTrue(delete.isEnabled)
        XCTAssertEqual(soundInfo(app), withMusic)
    }

    func testATapOnTheStripWhereNoBlockLiesClosesThePanel() {
        // At 6 seconds the strip is from x -159 to 261, so the 141 points right of the red block are empty.
        let app = startSound(seed: "music-wide", playhead: 3600)
        let region = element(app, "editor.soundRegion")
        let strip = element(app, "editor.timelineRegion")
        let red = element(app, "editor.clip.2")
        waitForThePanel(app, "the sound region at the start on music-wide with the playhead at 6 seconds")

        let past = CGVector(dx: (red.frame.maxX + strip.frame.maxX) / 2, dy: red.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(past).tap()
        waitUntil("the sound region gone after the tap past the last block") { !region.exists }
        XCTAssertFalse(element(app, "editor.delete").isEnabled)
        XCTAssertFalse(red.isSelected)
        XCTAssertEqual(soundInfo(app), withMusic)
    }

    func testOnTextWideTheSoundPanelTakesThePlaceOfTheTextPanelAndATapOnTheBarGivesItBack() {
        let app = startSound(seed: "text-wide")
        let textRegion = element(app, "editor.textRegion")
        let soundRegion = element(app, "editor.soundRegion")
        let bar = element(app, "editor.text.1")
        XCTAssertTrue(textRegion.exists)
        XCTAssertFalse(soundRegion.exists)

        openSound(app)
        waitUntil("the text region gone and no selected text after the tap on the sound button") {
            !textRegion.exists && textInfo(app) == "none"
        }
        XCTAssertTrue(bar.exists)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])
        screenshot("sound-panel-02-over-text")

        // The bar runs past the right edge of the screen: it is tapped in the middle of the part that is seen.
        let strip = element(app, "editor.timelineRegion")
        let seen = CGVector(dx: (bar.frame.minX + min(bar.frame.maxX, strip.frame.maxX)) / 2, dy: bar.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(seen).tap()
        waitUntil("the text region in place of the sound region after the tap on the bar") {
            textRegion.exists && !soundRegion.exists && position(app) == "1"
        }
        XCTAssertFalse(soundRegion.exists)
        XCTAssertEqual(position(app), "1")
    }

    func testOnTextWideATapOnThePictureGivesTheTextPanelBack() {
        let app = startSound(seed: "text-wide")
        let textRegion = element(app, "editor.textRegion")
        let soundRegion = element(app, "editor.soundRegion")

        openSound(app)
        waitUntil("the text region gone and no selected text after the tap on the sound button") {
            !textRegion.exists && textInfo(app) == "none"
        }
        XCTAssertTrue(element(app, "editor.text.1").exists)

        // The three lines stand in the middle of the picture.
        element(app, "editor.picture").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the text region in place of the sound region after the tap on the picture") {
            textRegion.exists && !soundRegion.exists && position(app) == "1"
        }
        XCTAssertFalse(soundRegion.exists)
        XCTAssertEqual(position(app), "1")
    }

    func testOnTwoClipsWideTheButtonOpensThePanel() {
        let app = startSound(seed: "two-clips-wide")
        XCTAssertFalse(element(app, "editor.soundRegion").exists)
        XCTAssertEqual(soundInfo(app), "100 . none")
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "2 clips, 2 files")
        XCTAssertTrue(element(app, "editor.sound").isEnabled)

        openSound(app)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])
        XCTAssertFalse(element(app, "editor.delete").isEnabled)
        XCTAssertEqual(soundInfo(app), "100 . none")
        screenshot("sound-panel-03-opened")
    }

    func testOnAnEmptyProjectTheSoundButtonIsThereAndNotEnabled() {
        let app = startSound(seed: "empty")
        let sound = element(app, "editor.sound")

        XCTAssertTrue(sound.exists)
        XCTAssertFalse(sound.isEnabled)
        XCTAssertFalse(element(app, "editor.soundRegion").exists)
    }

    func testInArabicThePanelMirrorsAndThePictureAndTheStripDoNot() {
        let app = startSound(seed: "music-wide", language: "ar")
        waitForThePanel(app, "the sound region at the start on music-wide in Arabic")

        // Leading is the right now: done is at the left end of its row, left of the three part buttons.
        let done = element(app, "sound.done")
        for tab in tabs {
            XCTAssertLessThan(done.frame.maxX, element(app, tab).frame.minX, tab)
        }
        XCTAssertGreaterThan(element(app, tabs[0]).frame.minX, element(app, tabs[1]).frame.minX)
        XCTAssertGreaterThan(element(app, tabs[1]).frame.minX, element(app, tabs[2]).frame.minX)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])
        // The preview and the strip do not mirror.
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertLessThan(element(app, "editor.clip.1").frame.minX, element(app, "editor.clip.2").frame.minX)
        XCTAssertEqual(soundInfo(app), withMusic)
        assertTheToolsRowFits(app, "ar")
        screenshot("sound-panel-01-music-ar")
    }

    func testInSwedishTheToolsRowFits() {
        let app = startSound(seed: "music-wide", language: "sv")
        waitForThePanel(app, "the sound region at the start on music-wide in Swedish")

        XCTAssertGreaterThan(element(app, "sound.done").frame.minX, element(app, tabs[2]).frame.maxX)
        XCTAssertEqual(soundInfo(app), withMusic)
        assertTheToolsRowFits(app, "sv")
        screenshot("sound-panel-01-music-sv")
    }

    /// Starts the app and waits for the editor: the first start on music-wide in a fresh simulator writes the tone.
    private func startSound(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func soundInfo(_ app: XCUIApplication) -> String {
        app.staticTexts["editor.soundInfo"].label
    }

    private func textInfo(_ app: XCUIApplication) -> String {
        app.staticTexts["editor.textInfo"].label
    }

    /// The first field of `editor.textInfo`: the position of the selected text, or "none".
    private func position(_ app: XCUIApplication) -> String {
        String(textInfo(app).split(separator: " ").first ?? "")
    }

    /// The part buttons that have the trait selected, in the order of the row.
    private func selectedTabs(_ app: XCUIApplication) -> [String] {
        tabs.filter { element(app, $0).isSelected }
    }

    /// Waits for the sound region with every button at its place: the four of the tools row in their row and
    /// the three part buttons in the row of done, so no picture is taken in a movement.
    private func waitForThePanel(_ app: XCUIApplication, _ what: String) {
        waitUntil(what) {
            element(app, "editor.soundRegion").exists && inOneRow(app, tools)
                && inOneRow(app, tabs + ["sound.done"])
        }
    }

    /// Taps the sound button and waits for the sound region.
    private func openSound(_ app: XCUIApplication) {
        element(app, "editor.sound").tap()
        waitForThePanel(app, "the sound region after the tap on the sound button, every button in its row")
    }

    /// No element of the sound region lies below the row of its part buttons.
    private func assertNothingUnderTheRow(_ app: XCUIApplication, _ when: String) {
        let row = element(app, "sound.done").frame
        let inside = element(app, "editor.soundRegion").descendants(matching: .any).allElementsBoundByIndex
        let below = inside.filter { $0.frame.minY >= row.maxY }
        print("sound-panel: after the tap on \(when) the region holds \(inside.count) elements, \(below.count) under the row")
        XCTAssertTrue(below.isEmpty, when)
    }

    /// The four buttons of the tools row lie whole inside the width of the screen and no two of their frames overlap.
    private func assertTheToolsRowFits(_ app: XCUIApplication, _ language: String) {
        let width = app.windows.firstMatch.frame.width
        let frames = tools.map { element(app, $0).frame }
        for index in 0..<tools.count {
            XCTAssertGreaterThanOrEqual(frames[index].minX, 0, language + " " + tools[index])
            XCTAssertLessThanOrEqual(frames[index].maxX, width, language + " " + tools[index])
            for other in (index + 1)..<tools.count {
                XCTAssertFalse(
                    frames[index].intersects(frames[other]), language + " " + tools[index] + " " + tools[other])
            }
        }
        let spans: [String] = frames.map { String(Double($0.minX)) + " to " + String(Double($0.maxX)) }
        print("sound-panel: in \(language) the tools row is \(spans) of \(width)")
    }

    /// True when all the controls are there and their middles lie at one height, within 4 points.
    private func inOneRow(_ app: XCUIApplication, _ identifiers: [String]) -> Bool {
        let controls = identifiers.map { element(app, $0) }
        guard controls.allSatisfy({ $0.exists }) else {
            return false
        }
        let heights = controls.map { Double($0.frame.midY) }
        return (heights.max() ?? 0) - (heights.min() ?? 0) <= 4
    }

    /// No element says when the frame is drawn, so the share is asked again until it is more than wanted.
    /// Prints the seconds it waited, gives up only above three times the expected seconds, and answers the
    /// last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, moreThan wanted: Double
    ) -> Double {
        let started = Date()
        var found = share(of: colour, in: picture)
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !(found > wanted) && waited <= first + 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print("sound-panel: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, for the effect of a tap. It fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds.
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
        print("sound-panel: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
