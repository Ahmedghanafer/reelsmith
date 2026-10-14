import XCTest

// The part clips of the sound panel, on the seed music-wide: the clips of two-clips-wide, blue 3 seconds and red 4
// on the landscape canvas, under the long test tone, with the panel open at the start. Every test first taps
// `sound.tab.clips`. The sound of the project is read from `editor.soundInfo` by the place of a field, counted
// from 1: field 1 is the volume of the clips times 100, field 2 "m" for muted or "." for not. That a change
// reached the player is read from the count of builds, the value of `editor.picture`, and once after the last
// change from a share of blue in the picture. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xctest/xcuielement/normalizedsliderposition
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/sliders
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class SoundClipsTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// B: at 00:00 the blue clip fills the picture area, so the share of blue is more than this. A build that
    /// failed leaves the picture black.
    private let blueOfTheClip = 0.9

    /// The seconds from a change to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The most moves toward the lower end the test makes before field 1 must read 0.
    private let mostMoves = 5

    private let withMusic = "100 . 0+4200 100 0 0"

    func testThePartClipsShowsTheSliderAndTheToggleOfTheProject() {
        let app = startClips()
        let slider = app.sliders["sound.clipVolume"]
        let toggle = element(app, "sound.clipsMuted")

        XCTAssertTrue(slider.exists)
        XCTAssertTrue(toggle.exists)
        XCTAssertFalse(toggle.isSelected)
        XCTAssertTrue(element(app, "sound.tab.clips").isSelected)
        XCTAssertEqual(soundInfo(app), withMusic)
        // The volume is 1, the upper end of the slider.
        print("sound-clips: the slider at \(slider.normalizedSliderPosition) with the volume of the clips at 1")
        XCTAssertGreaterThan(slider.normalizedSliderPosition, 0.9)
        // The toggle stands under the slider, at the leading end of its row, the left in English.
        XCTAssertGreaterThanOrEqual(toggle.frame.minY, slider.frame.maxY - 1)
        XCTAssertLessThan(toggle.frame.midX, slider.frame.midX)
        screenshot("sound-clips-01-clips")
    }

    /// A scripted move does not promise the place it lands on, so the first move asserts only the direction,
    /// and the moves are repeated until field 1 reads 0. Only then a move to the lower end changes nothing.
    func testAMoveTowardTheLowerEndLowersTheVolumeAndAMoveAtTheLowerEndBuildsNoItem() {
        let app = startClips()
        let slider = app.sliders["sound.clipVolume"]
        let picture = element(app, "editor.picture")
        let first = builds(picture)
        XCTAssertNotNil(first, "editor.picture has no count of builds")

        slider.adjust(toNormalizedSliderPosition: 0.5)
        waitUntil("field 1 below 100 and a higher count of builds after the move toward the lower end") {
            (volume(app) ?? 100) < 100 && (builds(picture) ?? 0) > (first ?? Int.max)
        }
        print("sound-clips: after the first move field 1 reads \(volume(app) ?? -1), editor.picture \(builds(picture) ?? -1)")
        XCTAssertLessThan(volume(app) ?? 100, 100)
        XCTAssertGreaterThan(builds(picture) ?? 0, first ?? Int.max)
        XCTAssertEqual(field(app, 2), ".")

        // Each move that lowers field 1 is followed until its count of builds has risen, so the build of one
        // move is never counted for the next.
        var moves = 0
        while volume(app) != 0 && moves < mostMoves {
            let before = volume(app) ?? 100
            let count = builds(picture)
            slider.adjust(toNormalizedSliderPosition: 0)
            moves += 1
            let lowered = waitUntil("field 1 below \(before) after move \(moves) to the lower end", required: false) {
                (volume(app) ?? 100) < before
            }
            // Also after a move that showed no effect in time, so a late build is not counted for the next move.
            waitUntil("a higher count of builds after move \(moves) to the lower end", required: lowered) {
                (builds(picture) ?? 0) > (count ?? Int.max)
            }
            print("sound-clips: after move \(moves) to the lower end field 1 reads \(volume(app) ?? -1), editor.picture \(builds(picture) ?? -1)")
        }
        XCTAssertEqual(volume(app), 0, "field 1 after \(moves) moves to the lower end")

        let atZero = builds(picture)
        slider.adjust(toNormalizedSliderPosition: 0)
        // Nothing comes to wait for, so the count is read 2 seconds after the move, as the criterion says.
        Thread.sleep(forTimeInterval: 2)
        let after = builds(picture)
        print("sound-clips: editor.picture at 0 \(atZero ?? -1) and 2 seconds after one more move \(after ?? -1)")
        XCTAssertEqual(after, atZero, "an item was built for a move that changed nothing")
        XCTAssertEqual(volume(app), 0)

        assertThePictureIsBuilt(app)
    }

    func testATapOnTheToggleMutesTheClipsAndASecondTapTakesTheMuteAway() {
        let app = startClips()
        let toggle = element(app, "sound.clipsMuted")
        let picture = element(app, "editor.picture")
        let first = builds(picture)
        XCTAssertNotNil(first, "editor.picture has no count of builds")

        toggle.tap()
        waitUntil("field 2 m, the toggle selected and a higher count of builds after the tap on it") {
            field(app, 2) == "m" && toggle.isSelected && (builds(picture) ?? 0) > (first ?? Int.max)
        }
        XCTAssertEqual(field(app, 2), "m")
        XCTAssertTrue(toggle.isSelected)
        XCTAssertEqual(field(app, 1), "100")
        XCTAssertGreaterThan(builds(picture) ?? 0, first ?? Int.max)
        screenshot("sound-clips-02-muted")

        let muted = builds(picture)
        toggle.tap()
        waitUntil("field 2 ., the toggle not selected and a higher count of builds after the second tap on it") {
            field(app, 2) == "." && !toggle.isSelected && (builds(picture) ?? 0) > (muted ?? Int.max)
        }
        XCTAssertEqual(field(app, 2), ".")
        XCTAssertFalse(toggle.isSelected)
        XCTAssertEqual(field(app, 1), "100")

        assertThePictureIsBuilt(app)
    }

    func testTheToggleShowsTheMuteOfTheProjectWhenThePanelIsMadeAgain() {
        let app = startClips()
        let toggle = element(app, "sound.clipsMuted")
        let region = element(app, "editor.soundRegion")
        let picture = element(app, "editor.picture")
        let first = builds(picture)

        toggle.tap()
        waitUntil("field 2 m, the toggle selected and a higher count of builds after the tap on it") {
            field(app, 2) == "m" && toggle.isSelected && (builds(picture) ?? 0) > (first ?? Int.max)
        }
        let muted = soundInfo(app)
        print("sound-clips: muted editor.soundInfo reads \(muted)")

        element(app, "sound.done").tap()
        waitUntil("the sound region gone after the tap on done") { !region.exists }
        element(app, "editor.sound").tap()
        waitUntil("the sound region after the tap on the sound button") { element(app, "sound.tab.clips").exists }
        element(app, "sound.tab.clips").tap()
        waitUntil("the toggle selected after the tap on sound.tab.clips") { toggle.exists && toggle.isSelected }
        XCTAssertTrue(toggle.isSelected)
        XCTAssertEqual(soundInfo(app), muted)

        assertThePictureIsBuilt(app)
    }

    func testInArabicThePartMirrorsAndThePictureAndTheStripDoNot() {
        let app = startClips(language: "ar")
        let slider = app.sliders["sound.clipVolume"]
        let toggle = element(app, "sound.clipsMuted")

        // Leading is the right now: the toggle stands at the right end of its row, right of the slider's middle.
        XCTAssertTrue(slider.exists)
        XCTAssertGreaterThan(toggle.frame.midX, slider.frame.midX)
        XCTAssertFalse(toggle.isSelected)
        // The preview and the strip do not mirror.
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertLessThan(element(app, "editor.clip.1").frame.minX, element(app, "editor.clip.2").frame.minX)
        XCTAssertEqual(soundInfo(app), withMusic)
        screenshot("sound-clips-01-clips-ar")
    }

    func testInSwedish() {
        let app = startClips(language: "sv")

        XCTAssertTrue(app.sliders["sound.clipVolume"].exists)
        XCTAssertTrue(element(app, "sound.clipsMuted").exists)
        XCTAssertEqual(soundInfo(app), withMusic)
        screenshot("sound-clips-01-clips-sv")
    }

    /// Starts on music-wide, waits for the editor and the panel, taps the part button and waits for the
    /// slider and the toggle of the part.
    private func startClips(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "music-wide", language: language)
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.clips after the start") { element(app, "sound.tab.clips").exists }
        element(app, "sound.tab.clips").tap()
        waitUntil("the slider and the toggle of the part clips after the tap on its part button") {
            app.sliders["sound.clipVolume"].exists && element(app, "sound.clipsMuted").exists
        }
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

    /// Field 1 as a number: the volume of the clips times 100.
    private func volume(_ app: XCUIApplication) -> Int? {
        Int(field(app, 1))
    }

    /// The value of `editor.picture` as a number: the count of the items the preview built.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    /// After the last change of a test: with the strip at 00:00 the share of blue in the picture is above B,
    /// which a build that failed cannot give.
    private func assertThePictureIsBuilt(_ app: XCUIApplication) {
        let time = element(app, "editor.time").label
        print("sound-clips: editor.time reads \(time)")
        XCTAssertEqual(time.components(separatedBy: " / ").first, "00:00")
        let found = waitForTheShare(of: blue, "blue", in: element(app, "editor.picture"), moreThan: blueOfTheClip)
        print("sound-clips: after the last change the share of blue is \(found), B \(blueOfTheClip)")
        XCTAssertGreaterThan(found, blueOfTheClip, "blue")
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
        print("sound-clips: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, for the effect of a tap or of a move of the slider. It fails only
    /// above three times the expected seconds: a hosted runner under load can hold the app for seconds.
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
        print("sound-clips: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
