import XCTest

// Levels while playing, on the seed music-wide: the clips of two-clips-wide, blue 3 seconds and red 4 on the
// landscape canvas, under the long test tone, with the sound panel open at the start. A level changed while the
// video plays leaves it playing: the time moves on, `editor.play` stays labelled pause and the count of builds in
// the value of `editor.picture` stays as it was. A change of the music's start still pauses and builds one item.
// The sound of the project is read from `editor.soundInfo` by the place of a field, counted from 1: field 1 is the
// volume of the clips times 100, field 2 "m" or ".", field 3 "<start>+<heard>" in ticks. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/sliders
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class LiveLevelsTests: XCTestCase {
    /// The most moves to the lower end before field 1 must read 0: a scripted move does not promise its place.
    private let mostMoves = 3

    /// E21: the volume of the clips to its lowest while playing, then the time read three times a second apart.
    func testTheVolumeOfTheClipsLoweredWhilePlayingLeavesTheVideoPlaying() {
        let pause = lowerTheClipsWhilePlaying(language: "en", picture: "live-levels-01-playing")
        XCTAssertEqual(pause, "Pause")
    }

    func testAChangeOfTheMusicStartWhilePlayingPausesAndBuildsOneItem() {
        let app = startApp(seed: "music-wide")
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.levels after the start") { element(app, "sound.tab.levels").exists }
        element(app, "sound.tab.levels").tap()
        let slider = app.sliders["sound.musicStart"]
        waitUntil("the slider sound.musicStart after the tap on its part button") { slider.exists }
        let play = element(app, "editor.play")
        let picture = element(app, "editor.picture")
        let still = play.label
        play.tap()
        waitUntil("editor.play labelled otherwise than \(still) after the tap on it") { play.label != still }
        let before = builds(picture)
        let start = field(app, 3)
        XCTAssertNotNil(before, "editor.picture has no count of builds")

        slider.adjust(toNormalizedSliderPosition: 1)
        waitUntil("field 3 changed, editor.play labelled \(still) and a higher count of builds after the move") {
            field(app, 3) != start && play.label == still && (builds(picture) ?? 0) > (before ?? Int.max)
        }
        print("live-levels: after the move of sound.musicStart while playing editor.soundInfo reads \(soundInfo(app)), editor.play \(play.label), editor.picture \(builds(picture) ?? -1) from \(before ?? -1)")
        XCTAssertNotEqual(field(app, 3), start)
        XCTAssertEqual(play.label, still)
        XCTAssertEqual(builds(picture), (before ?? -2) + 1)
    }

    func testInArabic() {
        _ = lowerTheClipsWhilePlaying(language: "ar", picture: "live-levels-01-playing-ar")
    }

    func testInSwedish() {
        _ = lowerTheClipsWhilePlaying(language: "sv", picture: "live-levels-01-playing-sv")
    }

    /// Starts on music-wide, taps `sound.tab.clips`, then `editor.play`, waits for the first second of the playback,
    /// moves `sound.clipVolume` to its lowest and reads the time three times one second apart. Asserts that each
    /// time is later than the one before, that `editor.play` keeps the label it took at the play, that the count
    /// of builds is the one before the move and that `editor.soundInfo` begins "0 .". Prints all of it, keeps the
    /// picture and answers the label of `editor.play` while playing.
    private func lowerTheClipsWhilePlaying(language: String, picture name: String) -> String {
        let app = startApp(seed: "music-wide", language: language)
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.clips after the start") { element(app, "sound.tab.clips").exists }
        element(app, "sound.tab.clips").tap()
        let slider = app.sliders["sound.clipVolume"]
        waitUntil("the slider sound.clipVolume after the tap on its part button") { slider.exists }
        let play = element(app, "editor.play")
        let picture = element(app, "editor.picture")
        let still = play.label

        mark("live-levels-01-play")
        let began = Date()
        play.tap()
        waitUntil("editor.play labelled otherwise than \(still) after the tap on it") { play.label != still }
        let pause = play.label
        waitUntil("the time at 00:01 or later after the tap on editor.play", expected: 2) {
            timeBeforeTheSlash(app) >= "00:01"
        }
        let before = builds(picture)
        XCTAssertNotNil(before, "editor.picture has no count of builds")

        var moves = 0
        while field(app, 1) != "0" && moves < mostMoves {
            slider.adjust(toNormalizedSliderPosition: 0)
            moves += 1
            waitUntil("field 1 at 0 after move \(moves) of sound.clipVolume to its lowest", required: false) {
                field(app, 1) == "0"
            }
        }
        print("live-levels: after \(moves) moves to the lowest, \(Date().timeIntervalSince(began)) seconds after the play, editor.soundInfo reads \(soundInfo(app))")

        var times: [String] = []
        for read in 1...3 {
            if read > 1 {
                // The reads are one second apart, which is what is measured: no effect to wait for.
                Thread.sleep(forTimeInterval: 1)
            }
            times.append(timeBeforeTheSlash(app))
        }
        let after = builds(picture)
        let info = soundInfo(app)
        print("live-levels: E21 in \(language): the time read \(times), editor.play \(play.label) (\(pause) at the play), editor.picture \(after ?? -1) from \(before ?? -1), editor.soundInfo \(info), \(Date().timeIntervalSince(began)) seconds after the play")
        XCTAssertLessThan(times[0], times[1], "the time stood after the level changed")
        XCTAssertLessThan(times[1], times[2], "the time stood after the level changed")
        XCTAssertEqual(play.label, pause, "editor.play after the level changed")
        XCTAssertEqual(after, before, "an item was built for a level")
        XCTAssertTrue(info.hasPrefix("0 ."), "editor.soundInfo reads \(info)")
        screenshot(name)
        return pause
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

    /// The time of `editor.time` before its slash, "mm:ss". Such texts are in the order of their times.
    private func timeBeforeTheSlash(_ app: XCUIApplication) -> String {
        element(app, "editor.time").label.components(separatedBy: " / ").first ?? ""
    }

    /// Reads until the condition holds, for the effect of a tap or of a move of a slider. Prints the seconds it
    /// waited and fails only above three times the expected seconds: a hosted runner under load can hold the app.
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
            Thread.sleep(forTimeInterval: 0.1)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("live-levels: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
