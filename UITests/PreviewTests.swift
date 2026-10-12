import XCTest

// The preview on the seeds two-clips (blue 1920 by 1080 for 3 seconds, then red 1080 by 1920 for 4,
// on the 9:16 canvas), two-clips-wide (the same clips on the 16:9 canvas) and empty.
// A UI test cannot see the colour of the picture: what the area shows is judged on the screenshots,
// and the tests read the frame of the area, the labels and the enabled states.
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
        XCTAssertEqual(play.label, "Pause")
        Thread.sleep(forTimeInterval: 2)
        play.tap()

        XCTAssertEqual(play.label, "Play")
        let stopped = timeBeforeTheSlash(app)
        XCTAssertTrue(["00:01", "00:02", "00:03"].contains(stopped), stopped)
        XCTAssertEqual(stopped, playheadValue(app))
        // The picture stands still: a second later the label is the same.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(timeBeforeTheSlash(app), stopped)
    }

    func testPlaybackRunsToTheEndPausesThereAndStartsAgainFromZero() {
        let app = startPreview(seed: "two-clips", playhead: 3600)
        let play = element(app, "editor.play")
        let time = element(app, "editor.time")
        XCTAssertEqual(time.label, "00:06 / 00:07")
        waitForThePicture()

        // The last second of the project. Expected 3 seconds with the tap, fails only above 9.
        let started = Date()
        play.tap()
        var waited = Date().timeIntervalSince(started)
        while time.label != "00:07 / 00:07" && waited <= 9 {
            Thread.sleep(forTimeInterval: 0.1)
            waited = Date().timeIntervalSince(started)
        }
        print("m1-7-preview: waited \(waited) seconds for the end of the project, expected 3")
        XCTAssertEqual(time.label, "00:07 / 00:07")
        XCTAssertLessThanOrEqual(waited, 9)
        // The player sent pause at the end.
        XCTAssertEqual(play.label, "Play")
        XCTAssertEqual(timeBeforeTheSlash(app), playheadValue(app))

        // From the end, play starts again from zero.
        play.tap()
        let restarted = timeBeforeTheSlash(app)
        XCTAssertTrue(["00:00", "00:01", "00:02"].contains(restarted), restarted)
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
        XCTAssertTrue(element(app, "editor.root").waitForExistence(timeout: 60))
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
