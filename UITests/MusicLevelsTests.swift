import XCTest

// The part levels of the sound panel, on the seed music-wide: the clips of two-clips-wide, blue 3 seconds and red 4
// on the landscape canvas, under the long test tone of 6000 ticks, of which 4200 are heard, with the panel open at
// the start. Every test there first taps `sound.tab.levels`. The sound of the project is read from
// `editor.soundInfo` by the place of a field, counted from 1: field 3 is "<start>+<heard>" in ticks, field 4 the
// volume of the music times 100, fields 5 and 6 the fade in and the fade out in ticks. That a change reached the
// player is read from the count of builds, the value of `editor.picture`, and once after the last change from a
// share of blue in the picture. A state with no music is read on two-clips-wide. No test listens.
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
final class MusicLevelsTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// B: at 00:00 the blue clip fills the picture area, so the share of blue is more than this. A build that
    /// failed leaves the picture black.
    private let blueOfTheClip = 0.9

    /// The seconds from a change to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The most moves toward the lower end the test makes before field 3 must read its start again.
    private let mostMoves = 5

    private let withMusic = "100 . 0+4200 100 0 0"
    private let startLabel = "00:00-00:07 / 00:10"
    private let sliders = ["sound.musicVolume", "sound.musicStart", "sound.fadeIn", "sound.fadeOut"]

    func testThePartLevelsShowsTheTimesAboveFourSlidersAtTheValuesOfTheProject() {
        let app = startLevels()
        let label = element(app, "sound.levelsLabel")

        XCTAssertEqual(label.label, startLabel)
        XCTAssertTrue(element(app, "sound.tab.levels").isSelected)
        XCTAssertFalse(element(app, "sound.noMusic").exists)
        XCTAssertEqual(soundInfo(app), withMusic)
        // The label above the four sliders, which stand one under the other in their order.
        let frames = sliders.map { app.sliders[$0].frame }
        XCTAssertLessThanOrEqual(label.frame.maxY, frames[0].minY + 1)
        for index in 1..<frames.count {
            XCTAssertGreaterThanOrEqual(frames[index].minY, frames[index - 1].maxY - 1, sliders[index])
        }
        // The sliders show the project: the volume 1 at the upper end, the start and both fades 0 at the lower.
        let places = sliders.map { app.sliders[$0].normalizedSliderPosition }
        print("music-levels: the sliders at \(places) with the volume at 1, the start and the fades at 0")
        XCTAssertGreaterThan(places[0], 0.9)
        for index in 1..<places.count {
            XCTAssertLessThan(places[index], 0.1, sliders[index])
        }
        screenshot("music-levels-01-levels")
    }

    /// A scripted move does not promise the place it lands on, so each move asserts the direction of its field
    /// and its limits, and no exact value but the two ends.
    func testEachSliderMovesItsFieldAndThePanelShowsTheValuesAgain() {
        let app = startLevels()
        let label = element(app, "sound.levelsLabel")

        let volume = move(app, "sound.musicVolume", to: 0.5, field: 4)
        XCTAssertLessThan(Int(volume) ?? 100, 100, "field 4 after the move of the volume toward its lower end")
        XCTAssertGreaterThanOrEqual(Int(volume) ?? -1, 0)

        let start = move(app, "sound.musicStart", to: 1, field: 3)
        let (begins, heard) = startAndHeard(start)
        XCTAssertGreaterThan(begins, 0, "the start in field 3 after the move toward the upper end")
        XCTAssertLessThanOrEqual(begins, 5400)
        XCTAssertGreaterThanOrEqual(heard, 600, "the heard length in field 3")
        XCTAssertLessThanOrEqual(heard, 4200)
        waitUntil("sound.levelsLabel reads another text after the move of the start") { label.label != startLabel }
        print("music-levels: after the move of the start sound.levelsLabel reads \(label.label)")
        XCTAssertNotEqual(label.label, startLabel)

        for (identifier, place) in [("sound.fadeIn", 5), ("sound.fadeOut", 6)] {
            let fade = Int(move(app, identifier, to: 1, field: place)) ?? -1
            XCTAssertGreaterThan(fade, 0, "field \(place) after the move of \(identifier) toward its upper end")
            XCTAssertLessThanOrEqual(fade, 3000, "field \(place)")
        }
        screenshot("music-levels-02-changed")
        assertThePictureIsBuilt(app)

        // The panel is made anew and shows the values of the project.
        let changed = soundInfo(app)
        let values = sliders.map { app.sliders[$0].value as? String ?? "" }
        print("music-levels: before done editor.soundInfo reads \(changed), the sliders \(values)")
        element(app, "sound.done").tap()
        waitUntil("the sound region gone after the tap on done") { !element(app, "editor.soundRegion").exists }
        element(app, "editor.sound").tap()
        waitUntil("the part button sound.tab.levels after the tap on the sound button") {
            element(app, "sound.tab.levels").exists
        }
        element(app, "sound.tab.levels").tap()
        waitUntil("the four sliders after the tap on sound.tab.levels") {
            sliders.allSatisfy { app.sliders[$0].exists }
        }
        let again = sliders.map { app.sliders[$0].value as? String ?? "" }
        print("music-levels: made anew editor.soundInfo reads \(soundInfo(app)), the sliders \(again)")
        XCTAssertEqual(soundInfo(app), changed)
        XCTAssertEqual(again, values)
    }

    func testTheStartMovedBackGivesTheTimesOfTheStartBack() {
        let app = startLevels()
        let label = element(app, "sound.levelsLabel")
        let picture = element(app, "editor.picture")

        let moved = startAndHeard(move(app, "sound.musicStart", to: 1, field: 3))
        XCTAssertGreaterThan(moved.begins, 0)
        waitUntil("sound.levelsLabel reads another text after the move of the start") { label.label != startLabel }
        XCTAssertNotEqual(label.label, startLabel)

        // Each move that lowers the start is followed until its count of builds has risen, so the build of one
        // move is never counted for the next.
        var moves = 0
        while field(app, 3) != "0+4200" && moves < mostMoves {
            let before = startAndHeard(field(app, 3)).begins
            let count = builds(picture)
            app.sliders["sound.musicStart"].adjust(toNormalizedSliderPosition: 0)
            moves += 1
            let lowered = waitUntil("the start in field 3 below \(before) after move \(moves) to the lower end", required: false) {
                startAndHeard(field(app, 3)).begins < before
            }
            // Also after a move that showed no effect in time, so a late build is not counted for the next move.
            waitUntil("a higher count of builds after move \(moves) to the lower end", required: lowered) {
                (builds(picture) ?? 0) > (count ?? Int.max)
            }
            print("music-levels: after move \(moves) to the lower end field 3 reads \(field(app, 3)), editor.picture \(builds(picture) ?? -1)")
        }
        XCTAssertEqual(field(app, 3), "0+4200", "field 3 after \(moves) moves to the lower end")
        waitUntil("sound.levelsLabel reads \(startLabel) again") { label.label == startLabel }
        XCTAssertEqual(label.label, startLabel)
        XCTAssertEqual(soundInfo(app), withMusic)

        assertThePictureIsBuilt(app)
    }

    func testWithNoMusicThePartShowsItsWordsAndNoSlider() {
        let app = startApp(seed: "two-clips-wide")
        waitForTheEditor(app)
        element(app, "editor.sound").tap()
        waitUntil("the part button sound.tab.levels after the tap on the sound button") {
            element(app, "sound.tab.levels").exists
        }
        element(app, "sound.tab.levels").tap()
        let none = element(app, "sound.noMusic")
        waitUntil("sound.noMusic after the tap on sound.tab.levels") { none.exists }

        XCTAssertEqual(none.label, "No music yet")
        XCTAssertTrue(element(app, "sound.tab.levels").isSelected)
        XCTAssertFalse(element(app, "sound.levelsLabel").exists)
        for identifier in sliders {
            XCTAssertFalse(element(app, identifier).exists, identifier)
        }
        XCTAssertEqual(element(app, "editor.soundRegion").descendants(matching: .slider).count, 0)
        XCTAssertEqual(soundInfo(app), "100 . none")
        screenshot("music-levels-03-no-music")
    }

    func testInArabicThePartMirrorsAndTheTimesAndThePictureAndTheStripDoNot() {
        let app = startLevels(language: "ar")
        let label = element(app, "sound.levelsLabel")
        let volume = app.sliders["sound.musicVolume"]

        // Leading is the right now: the label of the times stands right of the middle of the slider. It reads
        // its digits as in English.
        XCTAssertEqual(label.label, startLabel)
        XCTAssertGreaterThan(label.frame.midX, volume.frame.midX)
        XCTAssertTrue(sliders.allSatisfy { app.sliders[$0].exists })
        // The preview and the strip do not mirror.
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertLessThan(element(app, "editor.clip.1").frame.minX, element(app, "editor.clip.2").frame.minX)
        XCTAssertEqual(soundInfo(app), withMusic)
        screenshot("music-levels-01-levels-ar")
    }

    /// Starts on music-wide, waits for the editor and the panel, taps the part button and waits for the label
    /// and the four sliders of the part.
    private func startLevels(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "music-wide", language: language)
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.levels after the start") { element(app, "sound.tab.levels").exists }
        element(app, "sound.tab.levels").tap()
        waitUntil("the label and the four sliders of the part levels after the tap on its part button") {
            element(app, "sound.levelsLabel").exists && sliders.allSatisfy { app.sliders[$0].exists }
        }
        return app
    }

    /// Moves the slider toward the place, waits until its field reads another value and the count of builds reads
    /// as it should, and asserts that every other field reads as before. A level gives the standing item a new mix,
    /// so the count stays as it was. The start of the music builds a new item, so the count rises. Answers the field
    /// after the move.
    private func move(_ app: XCUIApplication, _ identifier: String, to place: CGFloat, field owned: Int) -> String {
        let picture = element(app, "editor.picture")
        let before = (1...6).map { field(app, $0) }
        let count = builds(picture)
        XCTAssertNotNil(count, "editor.picture has no count of builds")
        let rises = identifier == "sound.musicStart"
        app.sliders[identifier].adjust(toNormalizedSliderPosition: place)
        waitUntil("field \(owned) changed and " + (rises ? "a higher" : "the same") + " count of builds after the move of \(identifier)") {
            field(app, owned) != before[owned - 1]
                && (rises ? (builds(picture) ?? 0) > (count ?? Int.max) : builds(picture) == count)
        }
        let after = (1...6).map { field(app, $0) }
        print("music-levels: after the move of \(identifier) editor.soundInfo reads \(soundInfo(app)), editor.picture \(builds(picture) ?? -1) from \(count ?? -1)")
        if rises {
            XCTAssertGreaterThan(builds(picture) ?? 0, count ?? Int.max, identifier)
        } else {
            XCTAssertEqual(builds(picture), count, "an item was built for the level " + identifier)
        }
        for other in 1...6 where other != owned {
            XCTAssertEqual(after[other - 1], before[other - 1], "field \(other) after the move of \(identifier)")
        }
        return after[owned - 1]
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

    /// Field 3 as two numbers, the start and the heard length in ticks, or -1 for a part that is not a number.
    private func startAndHeard(_ field: String) -> (begins: Int, heard: Int) {
        let parts = field.split(separator: "+")
        guard parts.count == 2 else {
            return (-1, -1)
        }
        return (Int(parts[0]) ?? -1, Int(parts[1]) ?? -1)
    }

    /// The value of `editor.picture` as a number: the count of the items the preview built.
    private func builds(_ picture: XCUIElement) -> Int? {
        Int(picture.value as? String ?? "")
    }

    /// After the last change of a test: with the strip at 00:00 the share of blue in the picture is above B,
    /// which a build that failed cannot give.
    private func assertThePictureIsBuilt(_ app: XCUIApplication) {
        let time = element(app, "editor.time").label
        print("music-levels: editor.time reads \(time)")
        XCTAssertEqual(time.components(separatedBy: " / ").first, "00:00")
        let found = waitForTheShare(of: blue, "blue", in: element(app, "editor.picture"), moreThan: blueOfTheClip)
        print("music-levels: after the last change the share of blue is \(found), B \(blueOfTheClip)")
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
        print("music-levels: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, for the effect of a tap or of a move of a slider. It fails only above
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
        print("music-levels: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
