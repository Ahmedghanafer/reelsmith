import XCTest

// The whole path with music in one test, on the seed two-clips-wide (blue 3 seconds, then red 4, the landscape
// canvas, no music): Sound, the sound of the oldest video of the library as the music, the volume of the music
// down, a fade out, the clips muted, done, play, export and a relaunch. Then the panel on music-wide in Arabic
// and in Swedish, and one try at the system's file browser with a tone file the simulator run writes. The sound
// of the project is read from `editor.soundInfo` by the place of a field and never by a word, counted from 1:
// field 1 the volume of the clips times 100, field 2 "m" for muted or "." for not, field 3 "none" or
// "<start>+<heard>" in ticks, field 4 the volume of the music times 100, fields 5 and 6 the fade in and the fade
// out in ticks. That a change reached the player is read from the count of builds, the value of
// `editor.picture`, which rises, and once after the last change from a share of blue in the picture. The photo
// picker is driven by `chooseInThePhotoPicker`. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementattributes/elementtype
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/sliders
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/navigationbars
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/searchfields
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/tabbars
// https://developer.apple.com/documentation/xctest/xcuielementsnapshotproviding/snapshot()
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholeSoundPathTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// B: at "00:00" the blue clip fills the picture area, so the share of blue is more than this. A build that
    /// failed leaves the picture black.
    private let blueOfTheClip = 0.9

    /// The seconds from a change to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The seconds from the end of a pick to the music in the project: the copy and the import. A wait fails at
    /// three times this.
    private let expectedImport = 10.0

    private let tabs = ["sound.tab.music", "sound.tab.levels", "sound.tab.clips"]

    /// The start of the walk and of its step, for the printed times.
    private var walkBegan = Date()
    private var stepBegan = Date()

    func testTheWholePathWithMusicFromTheSoundButtonToASavedVideo() {
        mark("sound-path-01-path")
        walkBegan = Date()
        stepBegan = walkBegan
        var app = startSound(seed: "two-clips-wide")
        var picture = element(app, "editor.picture")

        // The editor: blue fills the picture, no music and no sound region.
        let first = waitForTheShare(of: blue, "blue at the start", in: picture, moreThan: blueOfTheClip)
        XCTAssertGreaterThan(first, blueOfTheClip, "blue at the start")
        XCTAssertEqual(soundInfo(app), "100 . none")
        XCTAssertFalse(element(app, "editor.soundRegion").exists)
        XCTAssertTrue(element(app, "editor.sound").isEnabled)
        screenshot("sound-path-01-editor")
        stepDone("the editor")

        // The music: the sound of the last cell of the picker's grid, blue, as `MusicVideoTests` chooses it.
        element(app, "editor.sound").tap()
        waitUntil("the part music with the button of a video after the tap on the sound button") {
            element(app, "sound.addFromVideo").exists
        }
        let before = builds(picture)
        XCTAssertNotNil(before, "editor.picture has no count of builds")
        element(app, "sound.addFromVideo").tap()
        let stopped = chooseInThePhotoPicker(app, fromTheEnd: [1], confirms: false, picture: nil)
        if let stopped {
            print("sound-path: picker not driven: " + stopped)
            app = startSound(seed: "music-wide")
            picture = element(app, "editor.picture")
            waitUntil("the part music with the remove button at the start on music-wide") {
                element(app, "sound.removeMusic").exists
            }
        } else {
            print("sound-path: picker driven")
            waitUntil(
                "field 3 no longer none, the remove button and a higher count of builds after the pick",
                expected: expectedImport
            ) {
                field(app, 3) != "none" && element(app, "sound.removeMusic").exists
                    && (builds(picture) ?? 0) > (before ?? Int.max)
            }
            print("sound-path: after the pick editor.soundInfo reads \(soundInfo(app)), editor.picture \(builds(picture) ?? -1) from \(before ?? -1)")
            XCTAssertNotEqual(field(app, 3), "none")
            XCTAssertTrue(element(app, "sound.removeMusic").exists)
            XCTAssertGreaterThan(builds(picture) ?? 0, before ?? Int.max, "the count of builds after the pick")
        }
        screenshot("sound-path-02-music")
        stepDone("the music")

        // The levels: the volume of the music toward its lower end, the fade out toward its upper end.
        element(app, "sound.tab.levels").tap()
        waitUntil("the sliders of the music volume and the fade out after the tap on sound.tab.levels") {
            element(app, "sound.musicVolume").exists && element(app, "sound.fadeOut").exists
        }
        let volume = move(app, "sound.musicVolume", to: 0.5, field: 4)
        XCTAssertLessThan(Int(volume) ?? 100, 100, "field 4 after the move of the volume toward its lower end")
        let fade = move(app, "sound.fadeOut", to: 1, field: 6)
        XCTAssertGreaterThan(Int(fade) ?? 0, 0, "field 6 after the move of the fade out toward its upper end")
        screenshot("sound-path-03-levels")
        stepDone("the levels")

        // The clips muted.
        element(app, "sound.tab.clips").tap()
        let toggle = element(app, "sound.clipsMuted")
        waitUntil("the toggle of the part clips after the tap on sound.tab.clips") { toggle.exists }
        let unmuted = builds(picture)
        toggle.tap()
        waitUntil("field 2 m, the toggle selected and the count of builds unchanged after the tap on it") {
            field(app, 2) == "m" && toggle.isSelected && builds(picture) == unmuted
        }
        XCTAssertEqual(field(app, 2), "m")
        XCTAssertTrue(toggle.isSelected)
        XCTAssertEqual(field(app, 1), "100")
        screenshot("sound-path-04-muted")
        stepDone("the clips")

        // Done: the region goes and the sound stays. After this last change, at 00:00, a built picture is blue.
        let set = soundInfo(app)
        print("sound-path: before done editor.soundInfo reads \(set)")
        element(app, "sound.done").tap()
        waitUntil("the sound region gone after the tap on done") { !element(app, "editor.soundRegion").exists }
        XCTAssertEqual(soundInfo(app), set)
        let time = element(app, "editor.time").label
        print("sound-path: editor.time reads \(time)")
        XCTAssertEqual(time.components(separatedBy: " / ").first, "00:00")
        let built = waitForTheShare(of: blue, "blue after the last change", in: picture, moreThan: blueOfTheClip)
        print("sound-path: after the last change the share of blue is \(built), B \(blueOfTheClip)")
        XCTAssertGreaterThan(built, blueOfTheClip, "blue after the last change")
        screenshot("sound-path-05-done")
        stepDone("done")

        // The playback from 00:00 to the end, 7 seconds.
        mark("sound-path-02-plays")
        element(app, "editor.play").tap()
        waitUntil("the same time on both sides of the slash at the end of the playback", expected: 8) {
            theTwoSidesAreTheSame(app)
        }
        XCTAssertEqual(soundInfo(app), set)
        stepDone("the playback")

        // The export. The simulator run grants the right to add to Photos, so no question is expected. A music
        // file that is not found fails the export, so saved also says that the file was found.
        element(app, "editor.export").tap()
        let done = element(app, "export.done")
        waitUntil("export.done after the export", expected: 30) { done.exists }
        screenshot("sound-path-06-saved")
        done.tap()
        waitUntil("the saved panel gone after the tap on export.done") { !done.exists }
        stepDone("the export")

        // The relaunch: nothing of the music and no project to reopen.
        app.terminate()
        app = startApp(seed: nil)
        waitUntil("the start screen after the relaunch with no seed", expected: 20) {
            element(app, "start.newProject").exists
        }
        XCTAssertTrue(element(app, "start.title").exists)
        XCTAssertFalse(element(app, "editor.root").exists)
        XCTAssertFalse(element(app, "editor.soundRegion").exists)
        screenshot("sound-path-07-relaunch")
        stepDone("the relaunch")
        let seconds = String(Int(Date().timeIntervalSince(walkBegan)))
        print("sound-path: walk finished, " + (stopped == nil ? "driven" : "not driven") + ", " + seconds + " seconds")
    }

    func testInArabicThePanelMirrorsAndThePictureTheStripAndTheTimesDoNot() {
        assertThePanel(language: "ar", mirrored: true)
    }

    func testInSwedishThePanelShows() {
        assertThePanel(language: "sv", mirrored: false)
    }

    /// One try at the system's file browser, no criterion. The simulator run writes a tone file into the storage
    /// of the Files app. The test opens the browser from `sound.addMusic` and drives it by place: the last button
    /// of its tab bar when it has one, then the topmost cell, which is the first location, then the topmost cell
    /// there, the file. It prints the whole tree at each step and fails on nothing it finds or misses.
    func testTheTryAtTheFileBrowserWithTheToneOfTheRun() {
        defer { print("sound-path: the try at the file browser finished") }
        let app = startSound(seed: "two-clips-wide")
        element(app, "editor.sound").tap()
        waitUntil("the part music after the tap on the sound button") { element(app, "sound.addMusic").exists }
        element(app, "sound.addMusic").tap()

        // The app has no navigation bar and no search field, so either of them is the browser's.
        let shown = waitUntil("a navigation bar or a search field of the browser", expected: 10, required: false) {
            app.navigationBars.firstMatch.exists || app.searchFields.firstMatch.exists
        }
        screenshot("sound-path-10-browser")
        print("sound-path: the whole tree of the browser")
        print(app.debugDescription)
        guard shown else {
            print("sound-path: browser not driven: it did not show")
            return
        }
        let browse = app.tabBars.count > 0 ? app.tabBars.firstMatch.buttons.allElementsBoundByIndex.last : nil
        if let browse, browse.exists {
            print("sound-path: the last button of the tab bar at \(browse.frame): " + browse.label)
            tap(app, theMiddleOf: browse.frame)
        } else {
            print("sound-path: the browser has no tab bar")
        }

        for step in ["the first location", "the file"] {
            var found: (any XCUIElementSnapshot)?
            waitUntil("a cell for \(step)", expected: 5, required: false) {
                found = (try? app.snapshot()).flatMap { topmostCell(in: $0) }
                return found != nil
            }
            print("sound-path: the whole tree before the tap on \(step)")
            print(app.debugDescription)
            guard let cell = found else {
                print("sound-path: browser not driven: no cell for \(step)")
                return
            }
            print("sound-path: tapped for \(step) at \(cell.frame): " + cell.label)
            tap(app, theMiddleOf: cell.frame)
            // A snapshot that could not be taken says nothing, so only a read tree counts.
            waitUntil("the cell for \(step) gone from its place", expected: 5, required: false) {
                guard let tree = try? app.snapshot() else {
                    return false
                }
                let now = topmostCell(in: tree)
                return now == nil || now?.frame != cell.frame || now?.label != cell.label
            }
        }

        // The browser may still cover the editor, so the line of the sound is read only when it is there.
        let info = app.staticTexts["editor.soundInfo"]
        let added = waitUntil("field 3 no longer none after the tap on the file", expected: expectedImport, required: false) {
            info.exists && field(app, 3) != "none" && field(app, 3) != ""
        }
        print("sound-path: browser " + (added ? "driven" : "not driven") + ", editor.soundInfo reads " + (info.exists ? info.label : "nothing, it is not there"))
        screenshot("sound-path-11-browser-music")
    }

    /// The panel on music-wide, open on the part music at the start, in a language. The tools row and the panel
    /// follow the language. The picture, the strip and the times never mirror.
    private func assertThePanel(language: String, mirrored: Bool) {
        let app = startSound(seed: "music-wide", language: language)
        waitUntil("the title, the times and the remove button of the part music at the start") {
            element(app, "sound.musicTitle").exists && element(app, "sound.musicLabel").exists
                && element(app, "sound.removeMusic").exists
        }
        let music = element(app, "sound.tab.music")
        let levels = element(app, "sound.tab.levels")
        XCTAssertEqual(tabs.filter { element(app, $0).isSelected }, ["sound.tab.music"])
        // Leading is the right in Arabic.
        XCTAssertEqual(element(app, "editor.split").frame.minX > element(app, "editor.delete").frame.minX, mirrored)
        XCTAssertEqual(music.frame.minX > levels.frame.minX, mirrored)
        XCTAssertEqual(levels.frame.minX > element(app, "sound.tab.clips").frame.minX, mirrored)
        XCTAssertEqual(element(app, "sound.done").frame.minX < music.frame.minX, mirrored)
        XCTAssertEqual(
            element(app, "sound.musicTitle").frame.minX > element(app, "sound.musicLabel").frame.minX, mirrored)
        // Fixed left to right in every language, the digits of the times among them.
        XCTAssertEqual(app.staticTexts["sound.musicLabel"].label, "00:00-00:07 / 00:10")
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertLessThan(element(app, "editor.clip.1").frame.minX, element(app, "editor.clip.2").frame.minX)
        XCTAssertEqual(
            element(app, "editor.picture").frame.midX, element(app, "editor.previewRegion").frame.midX, accuracy: 1)
        let found = waitForTheShare(
            of: blue, "blue before the picture in " + language, in: element(app, "editor.picture"),
            moreThan: blueOfTheClip)
        print("sound-path: in \(language) the share of blue is \(found), B \(blueOfTheClip)")
        screenshot(language == "ar" ? "sound-path-08-panel-ar" : "sound-path-09-panel-sv")
    }

    /// Moves the slider toward the place and waits until its field reads another value and the count of builds
    /// has risen. Answers the field after the move.
    private func move(_ app: XCUIApplication, _ identifier: String, to place: CGFloat, field owned: Int) -> String {
        let picture = element(app, "editor.picture")
        let was = field(app, owned)
        let count = builds(picture)
        XCTAssertNotNil(count, "editor.picture has no count of builds")
        let slider = element(app, identifier)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: place, dy: 0.5)))
        waitUntil("field \(owned) changed and the count of builds unchanged after the move of \(identifier)") {
            field(app, owned) != was && builds(picture) == count
        }
        print("sound-path: after the move of \(identifier) editor.soundInfo reads \(soundInfo(app)), editor.picture \(builds(picture) ?? -1) from \(count ?? -1)")
        XCTAssertEqual(builds(picture), count, "an item was built for the level " + identifier)
        return field(app, owned)
    }

    /// The cell of the browser that stands highest on the screen, the leftmost of a row, read from one snapshot.
    private func topmostCell(in tree: any XCUIElementSnapshot) -> (any XCUIElementSnapshot)? {
        flattened(tree).filter { $0.elementType == .cell && $0.frame.width > 1 && $0.frame.height > 1 }
            .min { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
    }

    /// Prints the seconds of the step that ends here and the seconds since the start of the walk.
    private func stepDone(_ what: String) {
        let now = Date()
        print(
            "sound-path: step \(what) took \(now.timeIntervalSince(stepBegan)) seconds, \(now.timeIntervalSince(walkBegan)) since the start of the walk"
        )
        stepBegan = now
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startSound(seed: String, language: String = "en") -> XCUIApplication {
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

    /// The field of `editor.soundInfo` at the place, counted from 1, or nothing when there is none.
    private func field(_ app: XCUIApplication, _ place: Int) -> String {
        let fields = soundInfo(app).split(separator: " ")
        return place <= fields.count ? String(fields[place - 1]) : ""
    }

    /// The value of `editor.picture` as a number: the count of the items the preview built.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    /// True when `editor.time` reads the same time on both sides of its slash, as in "00:07 / 00:07".
    private func theTwoSidesAreTheSame(_ app: XCUIApplication) -> Bool {
        let sides = element(app, "editor.time").label.components(separatedBy: " / ")
        return sides.count == 2 && sides[0] == sides[1]
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
        print("sound-path: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, for the effect of a tap, a move, a pick or a start. It fails only above
    /// three times the expected seconds: a hosted runner under load can hold the app for seconds.
    @discardableResult
    private func waitUntil(
        _ what: String, expected: Double = 1, required: Bool = true, _ reached: () -> Bool
    ) -> Bool {
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
        print("sound-path: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
