import XCTest

// The part music of the sound panel, on the seeds music-wide (the clips of two-clips-wide, blue 3 seconds and red
// 4 on the landscape canvas, under the long test tone, the panel open on the part music at the start) and
// two-clips-wide (no music). The sound of the project is read from `editor.soundInfo` and never by a word, a
// change that reached the player by the count of builds in the value of `editor.picture`, and the picture only
// through the probe `share(of:in:)`. The system's file browser runs outside the app: a test opens it and picks
// nothing in it. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/navigationbars
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/searchfields
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class AddMusicTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// B: at "00:00" the blue clip fills the picture area, so the share of blue is more than this. A picture
    /// that was not built is black.
    private let blueOfTheClip = 0.9

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The seconds from the tap on `sound.addMusic` to the system's browser on screen. Given up at three times this.
    private let expectedBrowser = 10.0

    private let tabs = ["sound.tab.music", "sound.tab.levels", "sound.tab.clips"]
    private let withMusic = "100 . 0+4200 100 0 0"
    private let title = "long-tone"
    private let times = "00:00-00:07 / 00:10"

    func testAStartOnMusicWideShowsTheTitleTheTimesAndBothButtons() {
        let app = startMusic(seed: "music-wide")
        waitForThePart(app, "the title, the times and both buttons at the start on music-wide") {
            self.element(app, "sound.musicTitle").exists && self.element(app, "sound.removeMusic").exists
        }

        XCTAssertEqual(app.staticTexts["sound.musicTitle"].label, title)
        XCTAssertEqual(app.staticTexts["sound.musicLabel"].label, times)
        XCTAssertEqual(element(app, "sound.addMusic").label, "Choose another file")
        XCTAssertTrue(element(app, "sound.addMusic").isEnabled)
        XCTAssertEqual(element(app, "sound.removeMusic").label, "Remove the music")
        XCTAssertFalse(element(app, "sound.importWords").exists)
        XCTAssertFalse(element(app, "sound.importOk").exists)
        // The rows lay out from leading to trailing: in English the title left of the times, add left of remove.
        XCTAssertLessThan(element(app, "sound.musicTitle").frame.maxX, element(app, "sound.musicLabel").frame.minX)
        XCTAssertLessThan(element(app, "sound.addMusic").frame.maxX, element(app, "sound.removeMusic").frame.minX)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])
        XCTAssertEqual(soundInfo(app), withMusic)
        screenshot("add-music-01-with-music")
    }

    func testRemoveTakesTheMusicAwayAndThePictureIsBuiltAgain() {
        let app = startMusic(seed: "music-wide")
        let picture = element(app, "editor.picture")
        waitForThePart(app, "the remove button at the start on music-wide") {
            self.element(app, "sound.removeMusic").exists
        }
        XCTAssertEqual(element(app, "editor.playhead").value as? String, "00:00")
        let first = waitForTheShare(of: blue, "blue before the removal", in: picture, moreThan: blueOfTheClip)
        XCTAssertGreaterThan(first, blueOfTheClip, "blue before the removal")
        let before = builds(picture)
        XCTAssertNotNil(Int(before), "editor.picture has no count of builds")

        element(app, "sound.removeMusic").tap()
        waitUntil("no music in editor.soundInfo and a higher count of builds after the tap on remove") {
            self.soundInfo(app) == "100 . none" && (Int(self.builds(picture)) ?? 0) > (Int(before) ?? Int.max)
        }
        print("add-music: editor.picture before the removal \(before) and after it \(builds(picture))")
        XCTAssertEqual(soundInfo(app), "100 . none")
        XCTAssertGreaterThan(Int(builds(picture)) ?? 0, Int(before) ?? Int.max, "the count of builds")
        XCTAssertFalse(element(app, "sound.musicTitle").exists)
        XCTAssertFalse(element(app, "sound.musicLabel").exists)
        XCTAssertFalse(element(app, "sound.removeMusic").exists)
        XCTAssertEqual(element(app, "sound.addMusic").label, "Add music from Files")
        XCTAssertTrue(element(app, "editor.soundRegion").exists)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])

        // After the last change, with the strip at the start: a build that failed leaves the picture black.
        XCTAssertEqual(element(app, "editor.playhead").value as? String, "00:00")
        let after = waitForTheShare(of: blue, "blue after the removal", in: picture, moreThan: blueOfTheClip)
        print("add-music: after the removal at 00:00 the share of blue is \(after), B \(blueOfTheClip)")
        XCTAssertGreaterThan(after, blueOfTheClip, "blue after the removal")
        screenshot("add-music-02-removed")
    }

    func testOnTwoClipsWideThePartOffersTheAddButtonAlone() {
        let app = startMusic(seed: "two-clips-wide")
        XCTAssertEqual(soundInfo(app), "100 . none")
        openSound(app)

        XCTAssertEqual(element(app, "sound.addMusic").label, "Add music from Files")
        XCTAssertTrue(element(app, "sound.addMusic").isEnabled)
        XCTAssertFalse(element(app, "sound.musicTitle").exists)
        XCTAssertFalse(element(app, "sound.musicLabel").exists)
        XCTAssertFalse(element(app, "sound.removeMusic").exists)
        XCTAssertFalse(element(app, "sound.importWords").exists)
        XCTAssertEqual(selectedTabs(app), ["sound.tab.music"])
        screenshot("add-music-03-no-music")
    }

    func testATapOnAddBringsTheSystemsFileBrowserOverTheEditor() {
        let app = startMusic(seed: "two-clips-wide")
        openSound(app)
        let add = element(app, "sound.addMusic")
        XCTAssertTrue(add.isEnabled)

        add.tap()
        // The app has no navigation bar and no search field, so either of them is the browser's. Nothing inside
        // the browser is asserted: the picture shows it.
        let started = Date()
        var found = browserElement(app)
        var waited = Date().timeIntervalSince(started)
        while found == nil && waited <= 3 * expectedBrowser {
            Thread.sleep(forTimeInterval: 0.5)
            found = browserElement(app)
            waited = Date().timeIntervalSince(started)
        }
        print("add-music: waited \(waited) seconds for an element of the browser, expected \(expectedBrowser), limit \(3 * expectedBrowser), found \(found ?? "none")")
        screenshot("add-music-04-browser")
        XCTAssertEqual(soundInfo(app), "100 . none")
        print("add-music: the test of the browser finished")
    }

    func testInArabicThePartMirrorsAndTheTitleAndTheTimesReadAsGiven() {
        let app = startMusic(seed: "music-wide", language: "ar")
        waitForThePart(app, "the title, the times and both buttons at the start on music-wide in Arabic") {
            self.element(app, "sound.musicTitle").exists && self.element(app, "sound.removeMusic").exists
        }

        XCTAssertEqual(app.staticTexts["sound.musicTitle"].label, title)
        XCTAssertEqual(app.staticTexts["sound.musicLabel"].label, times)
        // Leading is the right now: the title right of the times, add right of remove.
        XCTAssertGreaterThan(element(app, "sound.musicTitle").frame.minX, element(app, "sound.musicLabel").frame.maxX)
        XCTAssertGreaterThan(element(app, "sound.addMusic").frame.minX, element(app, "sound.removeMusic").frame.maxX)
        XCTAssertFalse(element(app, "sound.importWords").exists)
        XCTAssertEqual(soundInfo(app), withMusic)
        screenshot("add-music-01-with-music-ar")
    }

    /// Starts the app and waits for the editor: the first start on music-wide in a fresh simulator writes the tone.
    private func startMusic(seed: String, language: String = "en") -> XCUIApplication {
        let app = startApp(seed: seed, language: language)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func soundInfo(_ app: XCUIApplication) -> String {
        app.staticTexts["editor.soundInfo"].label
    }

    /// The value of `editor.picture`: the count of the items the preview built, or "none" with no value.
    private func builds(_ picture: XCUIElement) -> String {
        picture.value as? String ?? "none"
    }

    /// The part buttons that have the trait selected, in the order of the row.
    private func selectedTabs(_ app: XCUIApplication) -> [String] {
        tabs.filter { element(app, $0).isSelected }
    }

    /// The kind of the first element of the system's browser on screen, or nil while there is none.
    private func browserElement(_ app: XCUIApplication) -> String? {
        if app.navigationBars.firstMatch.exists {
            return "navigation bar"
        }
        if app.searchFields.firstMatch.exists {
            return "search field"
        }
        return nil
    }

    /// Waits for the sound region with the part music and what else the test names.
    private func waitForThePart(_ app: XCUIApplication, _ what: String, _ reached: @escaping () -> Bool) {
        waitUntil(what) {
            self.element(app, "editor.soundRegion").exists && self.element(app, "sound.addMusic").exists && reached()
        }
    }

    /// Taps the sound button and waits for the part music.
    private func openSound(_ app: XCUIApplication) {
        element(app, "editor.sound").tap()
        waitForThePart(app, "the part music after the tap on the sound button") { true }
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
        print("add-music: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
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
        print("add-music: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
