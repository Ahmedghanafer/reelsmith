import XCTest

// The music row of the strip on the seeds music-wide (blue 3 seconds and red 4 on the landscape canvas, under the
// long test tone of 10 seconds, titled "long-tone", the sound panel open at the start) and two-clips-wide (the
// same clips, no music). At 60 points a second the heard music is 7 seconds, 420 points. The screen is 402 points
// wide with the playhead at x 201, so at the start the blocks and the bar begin at x 201. Every launch starts
// with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
@MainActor
final class MusicRowTests: XCTestCase {
    func testTheStripHasARowOfMusicWithOneBarForTheHeardMusic() {
        let app = startRow(seed: "music-wide")
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")
        let bar = element(app, "editor.music")
        waitUntil("editor.music at the start on music-wide") { bar.exists }
        guard bar.exists else {
            return
        }

        print("music-row: the strip is \(region.frame.height) high, the bar at y \(bar.frame.minY - region.frame.minY), \(bar.frame.width) by \(bar.frame.height)")
        XCTAssertEqual(region.frame.height, 128, accuracy: 1)
        XCTAssertEqual(bar.frame.minY - region.frame.minY, 100, accuracy: 1)
        XCTAssertEqual(bar.frame.height, 24, accuracy: 1)
        XCTAssertEqual(bar.frame.minX, blue.frame.minX, accuracy: 1)
        XCTAssertEqual(bar.frame.width, 420, accuracy: 1)
        print("music-row: the label in en reads \(bar.label)")
        XCTAssertTrue(bar.label.contains("long-tone"), bar.label)
        screenshot("music-row-01-bar")
    }

    func testATapOnTheBarOpensTheSoundPanel() {
        let app = startRow(seed: "music-wide")
        let region = element(app, "editor.timelineRegion")
        let sound = element(app, "editor.soundRegion")
        let bar = element(app, "editor.music")
        waitUntil("the sound region at the start on music-wide") { sound.exists }

        element(app, "sound.done").tap()
        waitUntil("the sound region gone after the tap on done") { !sound.exists }
        XCTAssertTrue(bar.exists)
        guard bar.exists else {
            return
        }
        // The bar runs past the right edge of the screen: it is tapped in the middle of the part that is seen.
        let seen = CGVector(dx: (bar.frame.minX + min(bar.frame.maxX, region.frame.maxX)) / 2, dy: bar.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(seen).tap()
        waitUntil("the sound region after the tap on the music bar") { sound.exists }
    }

    func testWhileATextIsSelectedTheRowIsHiddenAndTheStripIsLower() {
        let app = startRow(seed: "music-wide")
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")
        let bar = element(app, "editor.music")
        waitUntil("editor.music at the start on music-wide") { bar.exists }

        element(app, "editor.addText").tap()
        waitUntil("the text region, a strip 104 high and no music bar after the tap on the text button") {
            element(app, "editor.textRegion").exists && abs(region.frame.height - 104) <= 1 && !bar.exists
        }
        XCTAssertEqual(region.frame.height, 104, accuracy: 1)
        XCTAssertFalse(bar.exists)

        // The clip row left of the blue block, which begins at the playhead line.
        let empty = CGVector(dx: (region.frame.minX + blue.frame.minX) / 2, dy: blue.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(empty).tap()
        waitUntil("a strip 128 high with the music bar after the tap on the empty strip") {
            !element(app, "editor.textRegion").exists && abs(region.frame.height - 128) <= 1 && bar.exists
        }
        XCTAssertEqual(region.frame.height, 128, accuracy: 1)
        XCTAssertTrue(bar.exists)
    }

    func testWithoutMusicTheRowIsEmpty() {
        let app = startRow(seed: "two-clips-wide")
        let region = element(app, "editor.timelineRegion")
        XCTAssertEqual(region.frame.height, 128, accuracy: 1)
        XCTAssertFalse(element(app, "editor.music").exists)
    }

    func testTheBarFollowsTheScale() {
        let app = startRow(seed: "music-wide")
        let blue = element(app, "editor.clip.1")
        let red = element(app, "editor.clip.2")
        let bar = element(app, "editor.music")
        waitUntil("editor.music at the start on music-wide") { bar.exists }

        mark("music-row-02-pinch")
        element(app, "editor.timelineRegion").pinch(withScale: 3, velocity: 1)
        waitUntil("editor.clip.1 wider than 270 after a pinch with scale 3") { blue.frame.width > 270 }
        print("music-row: after the pinch blue is \(blue.frame.width), red \(red.frame.width), the bar \(bar.frame.width)")
        XCTAssertTrue(bar.exists)
        XCTAssertEqual(bar.frame.width, blue.frame.width + red.frame.width, accuracy: 2)
        XCTAssertEqual(bar.frame.minX, blue.frame.minX, accuracy: 2)
    }

    func testInArabicAndSwedishTheBarRunsFromTheLeft() {
        for language in ["ar", "sv"] {
            let app = startRow(seed: "music-wide", language: language)
            let region = element(app, "editor.timelineRegion")
            let blue = element(app, "editor.clip.1")
            let bar = element(app, "editor.music")
            waitUntil("editor.music at the start on music-wide in \(language)") { bar.exists }
            guard bar.exists else {
                app.terminate()
                continue
            }
            // From the playhead line in the middle to the right, as in English.
            XCTAssertEqual(bar.frame.minX, blue.frame.minX, accuracy: 1, language)
            XCTAssertEqual(bar.frame.minX, region.frame.midX, accuracy: 1, language)
            XCTAssertEqual(bar.frame.width, 420, accuracy: 1, language)
            print("music-row: the label in \(language) reads \(bar.label)")
            XCTAssertTrue(bar.label.contains("long-tone"), bar.label)
            screenshot("music-row-01-bar-" + language)
            app.terminate()
        }
    }

    /// Reads until the condition holds, for the effect of a start, a tap or a pinch. It is expected within a second
    /// and fails only above three: a hosted runner under load can hold the app for seconds.
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
        print("music-row: waited \(waited) seconds for \(what), expected 1, limit 3")
        XCTAssertTrue(holds, what)
    }

    /// Starts the app with fresh drafts and waits for the editor: the first seeded start in a fresh simulator
    /// writes the clips first.
    private func startRow(seed: String, language: String = "en") -> XCUIApplication {
        let app = startApp(seed: seed, language: language, drafts: "fresh")
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
