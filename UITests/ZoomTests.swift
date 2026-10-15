import XCTest

// The zoom of the strip. On `three-clips` blue is 3 seconds, red 4, green 2, at 60 points a second when the
// editor opens, so the blocks are 180, 240 and 120 points wide. The screen is 402 points wide with the
// playhead at x 201. A scripted pinch gives about the scale it asks for, so a test that needs the scale
// reached reads it from the width of the blue block, which is 3 seconds long.
//
// https://developer.apple.com/documentation/xctest/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
@MainActor
final class ZoomTests: XCTestCase {
    func testAPinchOutwardZoomsInAroundThePlayhead() {
        // At 4.5 seconds the red block is under the playhead.
        let app = startZoom(seed: "three-clips", playhead: 2700)
        let region = element(app, "editor.timelineRegion")
        let playhead = element(app, "editor.playhead")

        // Each block carries the value of its clip: media, range, volume, video or photo.
        XCTAssertEqual(element(app, "editor.clip.1").value as? String, "blue 0+1800 100 v")
        XCTAssertEqual(element(app, "editor.clip.2").value as? String, "red 0+2400 100 v")
        XCTAssertEqual(element(app, "editor.clip.3").value as? String, "green 0+1200 100 v")

        mark("zoom-01-pinch-in")
        region.pinch(withScale: 3, velocity: 1)
        let blue = element(app, "editor.clip.1")
        waitUntil("editor.clip.1 wider than 270 after a pinch with scale 3") { blue.frame.width > 270 }
        print("zoom: editor.clip.1 is \(blue.frame.width) points wide after a pinch with scale 3")
        XCTAssertEqual(playhead.frame.midX, region.frame.midX, accuracy: 1)
        XCTAssertEqual(playheadValue(app), "00:04")
        screenshot("zoom-01-in")
    }

    func testTwoPinchesInwardZoomOutToTenPointsASecond() {
        let app = startZoom(seed: "three-clips", playhead: 2700)
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")

        mark("zoom-02-pinch-out")
        // A pinch inward has a velocity below zero, as in the pinches of TextGesturesTests.
        region.pinch(withScale: 0.2, velocity: -1)
        print("zoom: editor.clip.1 is \(blue.frame.width) points wide after one pinch with scale 0.2")
        region.pinch(withScale: 0.2, velocity: -1)
        waitUntil("editor.clip.1 30 points wide after two pinches with scale 0.2") {
            abs(blue.frame.width - 30) <= 1
        }
        XCTAssertEqual(blue.frame.width, 30, accuracy: 1)
        for position in 1...3 {
            XCTAssertEqual(element(app, "editor.clip." + String(position)).frame.height, 56, accuracy: 1)
        }
        XCTAssertEqual(playheadValue(app), "00:04")
        screenshot("zoom-02-out")
    }

    func testATrimAfterAPinchTrimsByThePointsAtTheNewScale() {
        // A scripted drag of 60 points reaches the pan of a handle as fewer points: the pan begins only
        // after the finger has moved a little, and that first stretch is not in its translation. So the
        // same drag is made first at the standard scale, where 10 points are 100 ticks, and the points
        // it gave are the points the drag after the pinch is expected to give.
        var app = startZoom(seed: "three-clips", playhead: 1800)
        mark("zoom-03-trim")
        let standard = trimBlueAtTheEnd(app, pointsPerSecond: 60)
        // A trim is rounded toward zero to a frame, so the points were from those of the trim to 2 more.
        let points = Double(1800 - standard) / 10 + 1
        print("zoom: at 60 points a second the drag of 60 points trimmed \(1800 - standard) ticks, so it gave \(points) points, within 1")
        app.terminate()

        // At 3 seconds the end of the blue block is under the playhead, at x 201.
        app = startZoom(seed: "three-clips", playhead: 1800)
        let blue = element(app, "editor.clip.1")
        element(app, "editor.timelineRegion").pinch(withScale: 3, velocity: 1)
        waitUntil("editor.clip.1 wider than 270 after a pinch with scale 3") { blue.frame.width > 270 }
        let pointsPerSecond = Double(blue.frame.width) / 3
        // As the strip computes it: ticks rounded toward zero, then to whole frames of 20 ticks.
        let trim = Int(points * 600 / pointsPerSecond) / 20 * 20
        let expected = 1800 - trim
        print("zoom: \(pointsPerSecond) points a second read before the drag, a trim of \(trim) ticks expected for \(points) points")
        let zoomed = trimBlueAtTheEnd(app, pointsPerSecond: pointsPerSecond, expected: expected)
        XCTAssertLessThanOrEqual(abs(zoomed - expected), 20)
    }

    /// Taps the blue block at 0.9 of its width, which is on the screen while its end is at x 201, and drags
    /// its end handle 60 points to the left. Gives the duration of blue that its value reads after the drag.
    private func trimBlueAtTheEnd(_ app: XCUIApplication, pointsPerSecond: Double, expected: Int? = nil) -> Int {
        let blue = element(app, "editor.clip.1")
        let end = element(app, "editor.trim.end")
        blue.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        waitUntil("the blue block selected after the tap on it") { blue.isSelected && end.exists }
        let start = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -60, dy: 0)))
        if let expected {
            waitUntil("a duration of blue within 20 ticks of \(expected) after the drag") {
                abs(self.duration(of: blue) - expected) <= 20
            }
        } else {
            waitUntil("a duration of blue below 1800 after the drag") { (0..<1800).contains(self.duration(of: blue)) }
        }
        print("zoom: at \(pointsPerSecond) points a second the value of editor.clip.1 after the drag is \(blue.value as? String ?? "")")
        return duration(of: blue)
    }

    func testTheTextBarFollowsTheScale() {
        // "BOX" is from 1 second for 1.5 seconds, and selected at the start.
        let app = startZoom(seed: "text-box-wide")
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")
        let bar = element(app, "editor.text.1")
        print("zoom: editor.textInfo before the pinch reads \(app.staticTexts["editor.textInfo"].label)")

        mark("zoom-04-text-bar")
        region.pinch(withScale: 3, velocity: 1)
        waitUntil("editor.clip.1 wider than 270 after a pinch with scale 3") { blue.frame.width > 270 }
        print("zoom: editor.textInfo after the pinch reads \(app.staticTexts["editor.textInfo"].label)")
        let pointsPerSecond = Double(blue.frame.width) / 3
        XCTAssertTrue(bar.exists)
        XCTAssertEqual(Double(bar.frame.minX - blue.frame.minX), pointsPerSecond, accuracy: 2)
        XCTAssertEqual(Double(bar.frame.width), 1.5 * pointsPerSecond, accuracy: 2)
    }

    func testInArabicAndSwedishTheZoomedStripRunsLeftToRight() {
        for language in ["ar", "sv"] {
            let app = startZoom(seed: "three-clips", language: language, playhead: 2700)
            let blocks = ["editor.clip.1", "editor.clip.2", "editor.clip.3"].map { element(app, $0) }
            element(app, "editor.timelineRegion").pinch(withScale: 3, velocity: 1)
            waitUntil("editor.clip.1 wider than 270 after a pinch with scale 3 in \(language)") {
                blocks[0].frame.width > 270
            }
            // Blue, red, green from the left, touching.
            XCTAssertEqual(blocks[0].frame.maxX, blocks[1].frame.minX, accuracy: 1)
            XCTAssertEqual(blocks[1].frame.maxX, blocks[2].frame.minX, accuracy: 1)
            XCTAssertLessThan(blocks[0].frame.minX, blocks[1].frame.minX)
            XCTAssertEqual(playheadValue(app), "00:04")
            screenshot("zoom-01-in-" + language)
            app.terminate()
        }
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startZoom(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    /// Reads until the condition holds, for the effect of a pinch, a tap or a drag. It is expected within
    /// a second and fails only above three: a hosted runner under load can hold the app for seconds.
    private func waitUntil(_ what: String, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !holds && waited <= first + 3 {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("zoom: waited \(waited) seconds for \(what), expected 1")
        XCTAssertTrue(holds, what)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// The duration in ticks from the value of a block, "<media> <start>+<duration> <volume> <v or p>",
    /// or minus one when the value has no such field.
    private func duration(of block: XCUIElement) -> Int {
        let fields = (block.value as? String ?? "").split(separator: " ")
        guard fields.count > 1, let range = fields[1].split(separator: "+").last else {
            return -1
        }
        return Int(range) ?? -1
    }
}
