import XCTest

// The preview on the seeds two-clips (blue 1920 by 1080 for 3 seconds, then red 1080 by 1920 for 4,
// on the 9:16 canvas), two-clips-wide (the same clips on the 16:9 canvas) and empty.
// What the area shows is judged on the screenshots, and the tests read the frame of the area, the labels
// and the enabled states. Only the play and pause test reads colours, through the probe `share(of:in:)`.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class PreviewTests: XCTestCase {
    func testTheFirstFrameIsInAnAreaOfTheShapeOfTheCanvas() {
        let app = startPreview(seed: "two-clips")
        let region = element(app, "editor.previewRegion")
        let picture = region.descendants(matching: .any)["editor.picture"]
        let play = region.descendants(matching: .any)["editor.play"]
        let time = region.descendants(matching: .any)["editor.time"]

        XCTAssertTrue(picture.exists)
        // 9:16, whole inside the region and in the middle of its width.
        assertTheShape(of: picture, between: 0.55, and: 0.58)
        XCTAssertGreaterThanOrEqual(picture.frame.minY, region.frame.minY - 1)
        XCTAssertLessThanOrEqual(picture.frame.maxY, region.frame.maxY + 1)
        XCTAssertLessThanOrEqual(picture.frame.width, region.frame.width + 1)
        XCTAssertEqual(picture.frame.midX, region.frame.midX, accuracy: 1)

        // Under the picture: the button and the label.
        XCTAssertTrue(play.exists)
        XCTAssertTrue(time.exists)
        XCTAssertGreaterThanOrEqual(play.frame.minY, picture.frame.maxY - 1)
        XCTAssertGreaterThanOrEqual(time.frame.minY, picture.frame.maxY - 1)
        XCTAssertEqual(time.label, "00:00 / 00:07")
        XCTAssertEqual(play.label, "Play")
        XCTAssertTrue(play.isEnabled)

        waitForThePicture()
        screenshot("m1-7-preview-01-first-frame")
    }

    func testPlayThenPauseTwoSecondsLater() {
        let app = startPreview(seed: "two-clips")
        let play = element(app, "editor.play")
        waitForThePicture()

        mark("m1-7-preview-01-play")
        play.tap()
        waitForTheButton(play, toRead: "Pause")
        // Only the player's reports move the time, so a play that starts nothing fails this wait.
        waitForTheTime(app, "the first second of the playback", expected: 2) { $0 >= "00:01" }
        // "mm:ss" texts are in the order of their times, and the project ends at "00:07".
        let atTheTap = timeBeforeTheSlash(app)
        print("m1-7-preview: the time read at the second tap is " + atTheTap)
        guard atTheTap < "00:07" else {
            XCTFail("the playback ended before the pause: the runner held the test")
            return
        }
        play.tap()

        waitForTheButton(play, toRead: "Play")
        XCTAssertEqual(play.label, "Play")
        let stopped = timeBeforeTheSlash(app)
        XCTAssertNotEqual(stopped, "00:00")
        XCTAssertLessThan(stopped, "00:07")
        XCTAssertEqual(stopped, playheadValue(app))
        // The label stands still: a second later it is the same.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(timeBeforeTheSlash(app), stopped)

        // The picture stands still: blue stands between black bars until the join at 3 seconds, then red
        // fills. A player that ran on after the pause shows red 4 seconds later.
        guard stopped < "00:03" else {
            print("m1-7-preview: the picture check was skipped, the pause came at " + stopped
                + " and blue ends at 00:03")
            return
        }
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(share(of: (r: 0, g: 0, b: 255), in: picture), 0.2, "blue at the pause")
        Thread.sleep(forTimeInterval: 4)
        XCTAssertGreaterThan(share(of: (r: 0, g: 0, b: 255), in: picture), 0.2, "blue 4 seconds after the pause")
        XCTAssertLessThan(share(of: (r: 255, g: 0, b: 0), in: picture), 0.5, "red 4 seconds after the pause")
    }

    func testPlaybackRunsToTheEndPausesThereAndStartsAgainFromZero() {
        let app = startPreview(seed: "two-clips", playhead: 3600)
        let play = element(app, "editor.play")
        let time = element(app, "editor.time")
        XCTAssertEqual(time.label, "00:06 / 00:07")
        waitForThePicture()

        // The last second of the project.
        play.tap()
        waitForTheTime(app, "the end of the project", expected: 3) { $0 == "00:07" }
        XCTAssertEqual(time.label, "00:07 / 00:07")
        // The player sent pause at the end.
        XCTAssertEqual(play.label, "Play")
        XCTAssertEqual(timeBeforeTheSlash(app), playheadValue(app))

        // From the end, play starts again from zero and the player moves: Core alone gives "00:00",
        // only the player's reports give "00:01".
        play.tap()
        waitForTheTime(app, "the first second after the restart", expected: 2) { $0 >= "00:01" && $0 < "00:07" }
        play.tap()
        XCTAssertEqual(play.label, "Play")
        XCTAssertEqual(timeBeforeTheSlash(app), playheadValue(app))
    }

    func testPlaybackPassesFromTheBlueClipIntoTheRedClip() {
        // Half a second before the join at 3 seconds, on the 9:16 canvas, where red fills the area.
        let app = startPreview(seed: "two-clips", playhead: 1500)
        let play = element(app, "editor.play")
        XCTAssertEqual(element(app, "editor.time").label, "00:02 / 00:07")
        waitForThePicture()

        play.tap()
        waitForTheTime(app, "a second inside the red clip", expected: 3) { $0 >= "00:04" }
        play.tap()
        XCTAssertEqual(play.label, "Play")
        XCTAssertEqual(timeBeforeTheSlash(app), playheadValue(app))
    }

    func testThePictureFollowsAScrubWhileNotPlaying() {
        let app = startPreview(seed: "two-clips", playhead: 3000)
        XCTAssertEqual(element(app, "editor.time").label, "00:05 / 00:07")
        waitForThePicture()
        screenshot("m1-7-preview-02-placed")

        // Nothing is selected, so no trim handle lies on the strip. To the right is earlier:
        // 5 seconds are 300 points, and a drag at the start leaves the start.
        for _ in 0..<3 {
            let start = element(app, "editor.timelineRegion")
                .coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 320, dy: 0)))
        }
        XCTAssertEqual(playheadValue(app), "00:00")
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:07")
        waitForThePicture()
        screenshot("m1-7-preview-03-after-scrub")
    }

    func testTheEmptyProjectHasABlackAreaAndNoPlay() {
        let app = startPreview(seed: "empty")
        XCTAssertTrue(element(app, "editor.picture").exists)
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:00")
        XCTAssertFalse(element(app, "editor.play").isEnabled)
        waitForThePicture()
        screenshot("m1-7-preview-04-empty")
    }

    func testInArabicThePreviewDoesNotMirror() {
        let app = startPreview(seed: "two-clips", language: "ar")
        let region = element(app, "editor.previewRegion")
        let picture = element(app, "editor.picture")
        let play = element(app, "editor.play")
        let time = element(app, "editor.time")

        // The digits 0 to 9, the Arabic line of the word file, and the same order from left to right.
        XCTAssertEqual(time.label, "00:00 / 00:07")
        XCTAssertEqual(play.label, "تشغيل")
        XCTAssertLessThan(play.frame.minX, time.frame.minX)
        assertTheShape(of: picture, between: 0.55, and: 0.58)
        XCTAssertEqual(picture.frame.midX, region.frame.midX, accuracy: 1)
        waitForThePicture()
        screenshot("m1-7-preview-01-first-frame-ar")
    }

    func testTheWideCanvasGivesAWideArea() {
        var app = startPreview(seed: "two-clips-wide")
        var region = element(app, "editor.previewRegion")
        var picture = element(app, "editor.picture")
        XCTAssertTrue(picture.exists)
        // 16:9 and as wide as the region.
        assertTheShape(of: picture, between: 1.74, and: 1.81)
        XCTAssertEqual(picture.frame.width, region.frame.width, accuracy: 1)
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:07")
        waitForThePicture()
        screenshot("m1-7-preview-05-wide")

        app = startPreview(seed: "two-clips-wide", playhead: 3000)
        region = element(app, "editor.previewRegion")
        picture = element(app, "editor.picture")
        assertTheShape(of: picture, between: 1.74, and: 1.81)
        XCTAssertEqual(picture.frame.width, region.frame.width, accuracy: 1)
        XCTAssertEqual(element(app, "editor.time").label, "00:05 / 00:07")
        waitForThePicture()
        screenshot("m1-7-preview-06-wide-bars")
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startPreview(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// The playhead part of `editor.time`, as in "00:02" of "00:02 / 00:07".
    private func timeBeforeTheSlash(_ app: XCUIApplication) -> String {
        element(app, "editor.time").label.components(separatedBy: " / ").first ?? ""
    }

    /// Reads the playhead part of `editor.time` until it is as wanted. Prints the seconds it waited and
    /// fails only above three times the expected seconds. "mm:ss" texts are in the order of their times.
    private func waitForTheTime(
        _ app: XCUIApplication, _ what: String, expected: Double, _ wanted: (String) -> Bool
    ) {
        let started = Date()
        var reached = wanted(timeBeforeTheSlash(app))
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !reached && waited <= first + 3 * expected {
            Thread.sleep(forTimeInterval: 0.1)
            reached = wanted(timeBeforeTheSlash(app))
            waited = Date().timeIntervalSince(started)
        }
        print("m1-7-preview: waited \(waited) seconds for \(what), expected \(expected)")
        XCTAssertTrue(reached, what)
    }

    /// Reads the label of the play button until it is as wanted, for the effect of a tap on it. Prints the
    /// seconds it waited, expected within 1 and failing only above 3.
    private func waitForTheButton(_ play: XCUIElement, toRead wanted: String) {
        let started = Date()
        var reached = play.label == wanted
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !reached && waited <= first + 3 {
            Thread.sleep(forTimeInterval: 0.1)
            reached = play.label == wanted
            waited = Date().timeIntervalSince(started)
        }
        print("m1-7-preview: waited \(waited) seconds for the button to read \(wanted), expected 1")
        XCTAssertTrue(reached, "the button did not read " + wanted + " within 3 seconds of the tap")
    }

    /// The width of the area divided by its height lies between the two numbers.
    private func assertTheShape(of picture: XCUIElement, between low: Double, and high: Double) {
        let frame = picture.frame
        XCTAssertGreaterThan(frame.height, 0)
        guard frame.height > 0 else {
            return
        }
        let shape = Double(frame.width / frame.height)
        XCTAssertGreaterThan(shape, low)
        XCTAssertLessThan(shape, high)
    }

    /// The item is built and the player seeks after the editor is on screen, and no element says when
    /// the frame is drawn. So a picture is taken two seconds later. This is a pause, never a limit.
    private func waitForThePicture() {
        Thread.sleep(forTimeInterval: 2)
    }
}
