import XCTest

// The timeline strip on the seed three-clips: blue 3 seconds, red 4, green 2, at 60 points a second.
//
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
@MainActor
final class TimelineTests: XCTestCase {
    func testTheClipsArePlainBlocksInOneRowAtTheFixedScale() {
        // 4.5 seconds is the middle of the strip, so a part of every block is on the screen.
        let app = startTimeline(seed: "three-clips", playhead: 2700)

        assertTheThreeBlocks(app)
        XCTAssertFalse(element(app, "editor.clip.4").exists)
        screenshot("m1-8-timeline-01-strip")

        // A pinch outward zooms the strip in: each block is wider.
        element(app, "editor.timelineRegion").pinch(withScale: 2, velocity: 1)
        waitUntil("editor.clip.1 wider than 180 after a pinch") { element(app, "editor.clip.1").frame.width > 181 }
        XCTAssertGreaterThan(element(app, "editor.clip.2").frame.width, 241)
        XCTAssertGreaterThan(element(app, "editor.clip.3").frame.width, 121)
    }

    func testThePlayheadIsOneLineInTheMiddle() {
        var app = startTimeline(seed: "three-clips")
        var playhead = element(app, "editor.playhead")
        XCTAssertTrue(playhead.exists)
        XCTAssertEqual(playhead.frame.midX, element(app, "editor.timelineRegion").frame.midX, accuracy: 1)
        XCTAssertLessThan(playhead.frame.width, playhead.frame.height)
        XCTAssertEqual(playheadValue(app), "00:00")
        // The left edge of the strip is under the line.
        XCTAssertEqual(element(app, "editor.clip.1").frame.minX, playhead.frame.midX, accuracy: 1)

        app = startTimeline(seed: "three-clips", playhead: 3000)
        playhead = element(app, "editor.playhead")
        XCTAssertEqual(playhead.frame.midX, element(app, "editor.timelineRegion").frame.midX, accuracy: 1)
        XCTAssertEqual(playheadValue(app), "00:05")
        // The red block is under the line.
        let red = element(app, "editor.clip.2")
        XCTAssertLessThan(red.frame.minX, playhead.frame.midX)
        XCTAssertGreaterThan(red.frame.maxX, playhead.frame.midX)
        screenshot("m1-8-timeline-02-placed")
    }

    func testADragScrubsAndStopsAtBothEnds() {
        let app = startTimeline(seed: "three-clips")
        mark("m1-8-timeline-01-scrub")

        // A drag to the right at the start leaves the start.
        drag(app, fromX: 0.5, byPoints: 120)
        XCTAssertEqual(playheadValue(app), "00:00")

        // To the left is later. The value is "mm:ss", so the order of the texts is the order of the times.
        drag(app, fromX: 0.5, byPoints: -120)
        let later = playheadValue(app)
        XCTAssertTrue(["00:01", "00:02", "00:03"].contains(later), later)

        drag(app, fromX: 0.5, byPoints: 120)
        let earlier = playheadValue(app)
        XCTAssertFalse(earlier.isEmpty)
        XCTAssertLessThan(earlier, later)

        // A long drag to the left stops at the end of the 9 seconds.
        for _ in 0..<3 {
            drag(app, fromX: 0.9, byPoints: -320)
        }
        XCTAssertEqual(playheadValue(app), "00:09")
    }

    func testATapSelectsABlockAndLeavesThePlayhead() {
        // At 4 seconds the middles of the blue and the red block are both on the screen.
        let app = startTimeline(seed: "three-clips", playhead: 2400)
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        let green = element(app, "editor.clip.3")
        XCTAssertFalse(blue.isSelected)
        XCTAssertFalse(red.isSelected)
        XCTAssertFalse(green.isSelected)

        red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        XCTAssertTrue(red.isSelected)
        XCTAssertFalse(blue.isSelected)
        XCTAssertFalse(green.isSelected)
        XCTAssertEqual(playheadValue(app), "00:04")
        screenshot("m1-8-timeline-03-selected")

        blue.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("the blue block selected after the tap on it") { blue.isSelected }
        XCTAssertTrue(blue.isSelected)
        XCTAssertFalse(red.isSelected)
        XCTAssertFalse(green.isSelected)
        XCTAssertEqual(playheadValue(app), "00:04")
    }

    func testTheEmptyProjectShowsThePlayheadAndNoBlock() {
        let app = startTimeline(seed: "empty")
        XCTAssertTrue(element(app, "editor.playhead").exists)
        XCTAssertFalse(element(app, "editor.clip.1").exists)
        XCTAssertEqual(playheadValue(app), "00:00")

        drag(app, fromX: 0.5, byPoints: -120)
        XCTAssertEqual(playheadValue(app), "00:00")
        XCTAssertFalse(element(app, "editor.clip.1").exists)
        screenshot("m1-8-timeline-04-empty")
    }

    func testInArabicTheStripDoesNotMirror() {
        let app = startTimeline(seed: "three-clips", language: "ar", playhead: 2700)

        // The same order from left to right, and the digits 0 to 9 on the blocks.
        assertTheThreeBlocks(app)
        XCTAssertEqual(playheadValue(app), "00:04")
        screenshot("m1-8-timeline-01-strip-ar")

        // Time still runs to the right: a drag to the left is later.
        mark("m1-8-timeline-02-scrub-ar")
        drag(app, fromX: 0.5, byPoints: -120)
        // The drag takes effect within a second: expected 1, fails only above 3.
        let started = Date()
        var waited: Double = 0
        while playheadValue(app) <= "00:04" && waited <= 3 {
            Thread.sleep(forTimeInterval: 0.1)
            waited = Date().timeIntervalSince(started)
        }
        print("m1-8-timeline: waited \(waited) seconds for a later playhead after the drag, expected 1")
        XCTAssertGreaterThan(playheadValue(app), "00:04")
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startTimeline(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    /// Reads until the condition holds, for the effect of a tap. It is expected within a second and fails
    /// only above three: a hosted runner under load can hold the app for seconds.
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
        print("m1-8-timeline: waited \(waited) seconds for \(what), expected 1")
        XCTAssertTrue(holds, what)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// Drags the strip sideways from a point of the timeline region. Minus is to the left.
    private func drag(_ app: XCUIApplication, fromX: Double, byPoints points: Double) {
        let start = element(app, "editor.timelineRegion")
            .coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)))
    }

    /// In one row inside the region, in track order from left to right, touching, 180, 240 and 120 points wide,
    /// each with its position and its length.
    private func assertTheThreeBlocks(_ app: XCUIApplication) {
        let region = element(app, "editor.timelineRegion")
        let blocks = ["editor.clip.1", "editor.clip.2", "editor.clip.3"].map { element(app, $0) }
        for block in blocks {
            XCTAssertTrue(block.exists)
        }
        guard blocks.allSatisfy({ $0.exists }) else {
            return
        }
        let frames = blocks.map { $0.frame }
        XCTAssertEqual(frames[0].width, 180, accuracy: 1)
        XCTAssertEqual(frames[1].width, 240, accuracy: 1)
        XCTAssertEqual(frames[2].width, 120, accuracy: 1)
        XCTAssertEqual(frames[0].maxX, frames[1].minX, accuracy: 1)
        XCTAssertEqual(frames[1].maxX, frames[2].minX, accuracy: 1)
        XCTAssertLessThan(frames[0].minX, frames[1].minX)
        XCTAssertLessThan(frames[1].minX, frames[2].minX)
        for frame in frames {
            XCTAssertEqual(frame.minY, frames[0].minY, accuracy: 1)
            XCTAssertGreaterThanOrEqual(frame.minY, region.frame.minY)
            XCTAssertLessThanOrEqual(frame.maxY, region.frame.maxY)
        }
        let texts = [("1", "00:03"), ("2", "00:04"), ("3", "00:02")]
        for (block, text) in zip(blocks, texts) {
            // The label is the text on the block: the position, then the length.
            XCTAssertTrue(block.label.hasPrefix(text.0), block.label)
            XCTAssertTrue(block.label.hasSuffix(text.1), block.label)
        }
    }
}
