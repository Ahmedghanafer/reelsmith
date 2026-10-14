import XCTest

// The button of the part music that takes the sound of a video, on the seeds music-wide (the clips of
// two-clips-wide, blue 3 seconds and red 4 on the landscape canvas, under the long test tone, the panel open on the
// part music at the start) and two-clips-wide (no music). The photo picker runs outside the app and is driven by
// `chooseInThePhotoPicker`: its last cell is the oldest video of the library, blue, 1800 ticks long with sound.
// The sound of the project is read from `editor.soundInfo` by the place of a field and never by a word, a change
// that reached the player by the count of builds in the value of `editor.picture`, and the picture only through
// the probe `share(of:in:)`. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class MusicVideoTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// B: at "00:00" the blue clip fills the picture area, so the share of blue is more than this. A picture
    /// that was not built is black.
    private let blueOfTheClip = 0.9

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The seconds from the end of the pick to the music in the project: the copy of a video of 3 seconds and
    /// its import. A wait fails at three times this.
    private let expectedImport = 10.0

    func testAStartOnMusicWideShowsTheButtonOfAVideoBesideTheOtherButtons() {
        let app = startMusic(seed: "music-wide")
        waitUntil("the button of a video and the remove button at the start on music-wide") {
            element(app, "sound.addFromVideo").exists && element(app, "sound.removeMusic").exists
        }

        let video = element(app, "sound.addFromVideo")
        XCTAssertEqual(video.label, "Use the sound of a video")
        XCTAssertTrue(video.isEnabled)
        XCTAssertTrue(element(app, "sound.addMusic").exists)
        // One row from leading to trailing: in English add, then remove, then the button of a video.
        XCTAssertEqual(video.frame.midY, element(app, "sound.removeMusic").frame.midY, accuracy: 2)
        XCTAssertLessThan(element(app, "sound.removeMusic").frame.maxX, video.frame.minX)
        XCTAssertFalse(element(app, "sound.importWords").exists)
        screenshot("music-video-01-button")
    }

    func testTheSoundOfTheLastVideoOfTheLibraryBecomesTheMusic() {
        mark("music-video-01-pick")
        defer { print("music-video: the test of the pick finished") }
        let app = startMusic(seed: "two-clips-wide")
        let picture = element(app, "editor.picture")
        XCTAssertEqual(soundInfo(app), "100 . none")
        element(app, "editor.sound").tap()
        waitUntil("the part music with the button of a video after the tap on the sound button") {
            element(app, "sound.addMusic").exists && element(app, "sound.addFromVideo").exists
        }
        let video = element(app, "sound.addFromVideo")
        XCTAssertTrue(video.isEnabled)
        XCTAssertEqual(video.frame.midY, element(app, "sound.addMusic").frame.midY, accuracy: 2)
        XCTAssertLessThan(element(app, "sound.addMusic").frame.maxX, video.frame.minX)

        XCTAssertEqual(element(app, "editor.playhead").value as? String, "00:00")
        let first = waitForTheShare(of: blue, "blue before the pick", in: picture, moreThan: blueOfTheClip)
        XCTAssertGreaterThan(first, blueOfTheClip, "blue before the pick")
        let before = builds(picture)
        XCTAssertNotNil(Int(before), "editor.picture has no count of builds")

        video.tap()
        let stopped = chooseInThePhotoPicker(app, fromTheEnd: [1], confirms: false, picture: "music-video-02-picker")
        if let stopped {
            print("music-video: picker not driven: " + stopped)
            return
        }
        print("music-video: picker driven")

        let added = waitUntil(
            "0+1800 in field 3 of editor.soundInfo, a higher count of builds and no words of an import after the pick",
            expected: expectedImport
        ) {
            field(3, of: app) == "0+1800" && (Int(builds(picture)) ?? 0) > (Int(before) ?? Int.max)
                && !element(app, "sound.importWords").exists
        }
        print("music-video: editor.soundInfo reads \(soundInfo(app)), editor.picture before the pick \(before) and after it \(builds(picture))")
        if !added {
            let open = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info").firstMatch.exists
            print("music-video: no music after the pick, the picker's grid still on screen: \(open)")
        }
        XCTAssertEqual(field(3, of: app), "0+1800")
        XCTAssertGreaterThan(Int(builds(picture)) ?? 0, Int(before) ?? Int.max, "the count of builds")
        XCTAssertFalse(element(app, "sound.importWords").exists)
        XCTAssertFalse(element(app, "sound.importOk").exists)
        XCTAssertEqual(app.staticTexts["sound.musicLabel"].label, "00:00-00:03 / 00:03")
        XCTAssertTrue(element(app, "sound.removeMusic").exists)
        // The title is the name the picker gave for the video, which may be none: the evidence says which.
        let title = app.staticTexts["sound.musicTitle"]
        print("music-video: the title " + (title.exists ? "reads \"" + title.label + "\"" : "is not there"))
        screenshot("music-video-03-added")

        // The clips are untouched, and after the last change, with the strip at the start, a build that failed
        // leaves the picture black.
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        XCTAssertEqual(field(1, of: app), "100")
        XCTAssertEqual(field(2, of: app), ".")
        XCTAssertEqual(element(app, "editor.playhead").value as? String, "00:00")
        let after = waitForTheShare(of: blue, "blue after the pick", in: picture, moreThan: blueOfTheClip)
        print("music-video: after the pick at 00:00 the share of blue is \(after), B \(blueOfTheClip)")
        XCTAssertGreaterThan(after, blueOfTheClip, "blue after the pick")
    }

    func testInArabicTheButtonOfAVideoMirrors() {
        let app = startMusic(seed: "music-wide", language: "ar")
        waitUntil("the button of a video and the remove button at the start on music-wide in Arabic") {
            element(app, "sound.addFromVideo").exists && element(app, "sound.removeMusic").exists
        }

        let video = element(app, "sound.addFromVideo")
        XCTAssertTrue(video.isEnabled)
        // Leading is the right now: the button of a video left of remove.
        XCTAssertEqual(video.frame.midY, element(app, "sound.removeMusic").frame.midY, accuracy: 2)
        XCTAssertLessThan(video.frame.maxX, element(app, "sound.removeMusic").frame.minX)
        screenshot("music-video-01-button-ar")
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

    /// Field n of `editor.soundInfo`, counted from 1, or "missing" when there is no such field.
    private func field(_ n: Int, of app: XCUIApplication) -> String {
        let fields = soundInfo(app).components(separatedBy: " ")
        return n <= fields.count ? fields[n - 1] : "missing"
    }

    /// The value of `editor.picture`: the count of the items the preview built, or "none" with no value.
    private func builds(_ picture: XCUIElement) -> String {
        picture.value as? String ?? "none"
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
        print("music-video: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
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
        print("music-video: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
        return holds
    }
}
