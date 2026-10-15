import XCTest

// Levels that follow the finger. A level slider sends each value of a drag, the whole drag one step of undo and one
// write of the draft, and while the video plays it leaves it playing. A drag is one press of 0.1 seconds on the
// thumb, then a move to past one end at 200 points a second, so it takes more than a second. The seed music-wide
// is the clips of two-clips-wide, blue 3 seconds and red 4 on the landscape canvas, under the long test tone, with
// the sound panel open at the start. The sound of the project is read from `editor.soundInfo` by the place of a
// field, counted from 1: field 1 is the volume of the clips times 100, field 2 "m" or ".", field 4 the volume of
// the music times 100, field 5 the fade in in ticks. A clip is read by the value of its block, "<media>
// <start>+<duration> <volume times 100> <v or p>". Every start is with `-drafts fresh`, so the drag is the only
// step and one undo leaves `editor.undo` disabled. The count of builds is the value of `editor.picture`. That the
// level moves under the finger is read by the QA pass in the recording from the mark `follow-01-drag`, and heard
// on the phone. No test listens.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:withvelocity:thenholdforduration:)
// https://developer.apple.com/documentation/xcuiautomation/xcuigesturevelocity
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class FollowFingerTests: XCTestCase {
    /// Half the width of the thumb: the track runs from this far inside one end of the slider to as far inside the
    /// other.
    private let thumbHalf: CGFloat = 14

    /// The points a second of a drag.
    private let speed: CGFloat = 200

    /// The seconds a start of a draft from the start screen is expected to take. A wait fails at three times this.
    private let expectedStart = 20.0

    func testADragWhilePlayingLeavesTheVideoPlayingAndIsOneUndoStep() {
        let app = dragTheClipsWhilePlaying(language: "en", picture: "follow-01-dragged")
        let undo = element(app, "editor.undo")
        undo.tap()
        waitUntil("editor.soundInfo beginning 100 . after one undo") { self.soundInfo(app).hasPrefix("100 .") }
        print("follow: after one undo editor.soundInfo reads \(soundInfo(app)), editor.undo enabled \(undo.isEnabled)")
        XCTAssertTrue(soundInfo(app).hasPrefix("100 ."), soundInfo(app))
        XCTAssertFalse(undo.isEnabled)
    }

    func testTheDraggedLevelIsKeptInTheDraft() {
        var app = dragTheClipsWhilePlaying(language: "en", picture: nil)
        app.terminate()
        app = startApp(seed: nil, drafts: "kept")
        waitUntil("drafts.row.1 on the start screen", expected: expectedStart) {
            self.element(app, "drafts.row.1").exists
        }
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        waitUntil("editor.soundInfo beginning 0 . in the reopened draft") { self.soundInfo(app).hasPrefix("0 .") }
        print("follow: in the reopened draft editor.soundInfo reads \(soundInfo(app))")
        XCTAssertTrue(soundInfo(app).hasPrefix("0 ."), soundInfo(app))
    }

    func testInArabic() {
        _ = dragTheClipsWhilePlaying(language: "ar", picture: "follow-01-dragged-ar")
    }

    func testInSwedish() {
        _ = dragTheClipsWhilePlaying(language: "sv", picture: "follow-01-dragged-sv")
    }

    func testADragOfTheVolumeOfRedIsOneUndoStep() {
        // At 4 seconds red is from x 141 to 381.
        let app = startApp(seed: "two-clips-wide", playhead: 2400, drafts: "fresh")
        waitForTheEditor(app)
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("editor.clip.2 selected and the slider clip.volume") {
            red.isSelected && app.sliders["clip.volume"].exists
        }
        // The volume is 1 of 0 to 2: the thumb stands in the middle.
        drag(app.sliders["clip.volume"], from: 0.5, toHighest: false)
        waitUntil("editor.clip.2 ending 0 v after the drag") { self.value(app, "editor.clip.2").hasSuffix(" 0 v") }
        print("follow: after the drag of clip.volume editor.clip.2 reads " + value(app, "editor.clip.2"))
        XCTAssertTrue(value(app, "editor.clip.2").hasSuffix(" 0 v"), value(app, "editor.clip.2"))
        undoOnce(app) { self.value(app, "editor.clip.2").hasSuffix(" 100 v") }
    }

    func testADragOfTheVolumeOfTheMusicIsOneUndoStep() {
        let app = startLevels()
        // The volume is 1: the thumb stands at the higher end.
        drag(app.sliders["sound.musicVolume"], from: 1, toHighest: false)
        waitUntil("field 4 at 0 after the drag") { self.field(app, 4) == "0" }
        print("follow: after the drag of sound.musicVolume editor.soundInfo reads \(soundInfo(app))")
        XCTAssertEqual(field(app, 4), "0")
        undoOnce(app) { self.field(app, 4) == "100" }
    }

    /// The fade in begins at 0, its lowest, so it is dragged to its highest, 3000 ticks.
    func testADragOfTheFadeInIsOneUndoStep() {
        let app = startLevels()
        drag(app.sliders["sound.fadeIn"], from: 0, toHighest: true)
        waitUntil("field 5 at 3000 after the drag") { self.field(app, 5) == "3000" }
        print("follow: after the drag of sound.fadeIn editor.soundInfo reads \(soundInfo(app))")
        XCTAssertEqual(field(app, 5), "3000")
        undoOnce(app) { self.field(app, 5) == "0" }
    }

    /// Starts on music-wide at the playhead 0 with fresh drafts, taps `sound.tab.clips`, finds the slider, taps
    /// `editor.play` and waits for the time to move. Then one drag of `sound.clipVolume` to its lowest end, the
    /// right end in Arabic. After it the time is read twice a second apart and is later each time, `editor.play`
    /// keeps its label of pause, the count of builds is the one of before the drag and `editor.soundInfo` begins
    /// "0 .". Prints all of it, keeps the picture when it is named and answers the app.
    private func dragTheClipsWhilePlaying(language: String, picture name: String?) -> XCUIApplication {
        let app = startApp(seed: "music-wide", language: language, playhead: 0, drafts: "fresh")
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.clips after the start") { self.element(app, "sound.tab.clips").exists }
        element(app, "sound.tab.clips").tap()
        let slider = app.sliders["sound.clipVolume"]
        waitUntil("the slider sound.clipVolume after the tap on its part button") { slider.exists }
        let play = element(app, "editor.play")
        let picture = element(app, "editor.picture")
        let still = play.label
        let end = element(app, "editor.time").label.components(separatedBy: " / ").last ?? ""

        play.tap()
        waitUntil("editor.play labelled otherwise than \(still) after the tap on it") { play.label != still }
        let pause = play.label
        waitUntil("the time past 00:00 after the tap on editor.play", expected: 2) { self.time(app) != "00:00" }
        let before = builds(picture)
        XCTAssertNotNil(before, "editor.picture has no count of builds")

        mark("follow-01-drag")
        // The volume of the clips is 1: the thumb stands at the higher end.
        drag(slider, from: 1, toHighest: false, mirrored: language == "ar")
        waitUntil("field 1 at 0 after the drag of sound.clipVolume to its lowest") { self.field(app, 1) == "0" }

        let first = time(app)
        Thread.sleep(forTimeInterval: 1)
        let second = time(app)
        print("follow: in \(language) after the drag the time reads \(first) then \(second) a second later, the project ends at \(end), editor.play \(play.label), editor.picture \(builds(picture) ?? -1) from \(before ?? -1), editor.soundInfo \(soundInfo(app))")
        XCTAssertNotEqual(first, "00:00")
        XCTAssertNotEqual(second, end, "timing, not the product: the playback reached its end before the second read")
        XCTAssertLessThan(first, second, "the time stood after the drag")
        XCTAssertEqual(play.label, pause)
        XCTAssertEqual(builds(picture), before, "an item was built for a level")
        XCTAssertTrue(soundInfo(app).hasPrefix("0 ."), soundInfo(app))
        if let name {
            screenshot(name)
        }
        return app
    }

    /// Starts on music-wide with fresh drafts and taps `sound.tab.levels`.
    private func startLevels() -> XCUIApplication {
        let app = startApp(seed: "music-wide", drafts: "fresh")
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.levels after the start") { self.element(app, "sound.tab.levels").exists }
        element(app, "sound.tab.levels").tap()
        waitUntil("the sliders sound.musicVolume and sound.fadeIn after the tap on sound.tab.levels") {
            app.sliders["sound.musicVolume"].exists && app.sliders["sound.fadeIn"].exists
        }
        return app
    }

    /// One drag from the thumb, standing at the share of the track from its lower end, to 30 points past the lowest
    /// or the highest end. A mirrored slider has its lower end at the right.
    private func drag(_ slider: XCUIElement, from share: CGFloat, toHighest: Bool, mirrored: Bool = false) {
        let width = slider.frame.width
        let left = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let along = thumbHalf + (width - 2 * thumbHalf) * share
        let thumb = left.withOffset(CGVector(dx: mirrored ? width - along : along, dy: 0))
        // The end at the right when the drag goes up in English or down in Arabic.
        let right = toHighest != mirrored
        let target = left.withOffset(CGVector(dx: right ? width + 30 : -30, dy: 0))
        print("follow: the slider at \(slider.frame), mirrored \(mirrored), the thumb at \(thumb.screenPoint), the drag to \(target.screenPoint)")
        let began = Date()
        thumb.press(
            forDuration: 0.1, thenDragTo: target, withVelocity: XCUIGestureVelocity(rawValue: speed),
            thenHoldForDuration: 0)
        print("follow: the drag took \(Date().timeIntervalSince(began)) seconds")
    }

    /// One tap on `editor.undo`, then the condition holds and `editor.undo` is disabled: the drag was one step.
    private func undoOnce(_ app: XCUIApplication, _ undone: @escaping () -> Bool) {
        let undo = element(app, "editor.undo")
        undo.tap()
        waitUntil("the value of before the drag after one undo") { undone() }
        print("follow: after one undo editor.soundInfo reads \(soundInfo(app)), editor.undo enabled \(undo.isEnabled)")
        XCTAssertTrue(undone())
        XCTAssertFalse(undo.isEnabled)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        element(app, identifier).value as? String ?? ""
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
    private func time(_ app: XCUIApplication) -> String {
        element(app, "editor.time").label.components(separatedBy: " / ").first ?? ""
    }

    /// Reads until the condition holds, for the effect of a tap or of a drag. Prints the seconds it waited and fails
    /// only above three times the expected seconds: a hosted runner under load can hold the app.
    private func waitUntil(_ what: String, expected: Double = 1, _ reached: () -> Bool) {
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
        print("follow: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
