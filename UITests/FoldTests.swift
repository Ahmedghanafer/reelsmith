import XCTest

// Folding the frames of the blocks with the button `editor.frames` at the trailing end of the tools row. Unfolded the
// strip is 128 points high (104 with a selected text) with blocks of 56, folded 96 (72) with blocks of 24, the text
// row at y 40 and the music row at y 68 of the strip. On `music-wide` blue is 3 seconds and red 4 under the long test
// tone, the sound panel open at the start. On `two-clips-wide` at 1800 ticks blue runs from x 21 to 201 and its end
// handle from 201 to 225. On `three-clips` at 3300 ticks green's middle is at x 351 and red's left end at x 51. On
// `text-box-wide` the text "BOX" is selected at the start. The screen is 402 points wide. Every first launch starts
// with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/ishittable
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
@MainActor
final class FoldTests: XCTestCase {
    private let order = [
        "editor.split", "editor.delete", "editor.addText", "editor.sound", "editor.addClips", "editor.frames",
    ]

    func testTheSixButtonsStandInOneRowAndTheFoldedStripInArabicAndSwedish() {
        for language in ["en", "ar", "sv"] {
            let app = startFold(seed: "music-wide", language: language)
            let frames = order.map { element(app, $0).frame }
            for (index, frame) in frames.enumerated() {
                print("fold: in \(language) " + order[index] + " at \(frame), hittable \(element(app, order[index]).isHittable)")
                XCTAssertTrue(element(app, order[index]).isHittable, order[index] + " in " + language)
                XCTAssertEqual(Double(frame.midY), Double(frames[0].midY), accuracy: 2, order[index] + " in the row")
                if index > 0 {
                    // Leading to trailing: from the left in English and Swedish, from the right in Arabic.
                    if language == "ar" {
                        XCTAssertLessThan(frame.maxX, frames[index - 1].minX, order[index] + " after the one before")
                    } else {
                        XCTAssertLessThan(frames[index - 1].maxX, frame.minX, order[index] + " after the one before")
                    }
                }
            }
            XCTAssertEqual(Double(frames[5].width), 44, accuracy: 1)
            XCTAssertEqual(Double(frames[5].height), 44, accuracy: 1)
            if language != "en" {
                fold(app)
                assertFolded(app, textSelected: false)
                screenshot("fold-01-folded-" + language)
            }
            app.terminate()
        }
    }

    func testTheButtonFoldsAndUnfoldsTheBlocksAndLeavesNoUndoStep() {
        var app = startFold(seed: "music-wide")
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")
        let picture = element(app, "editor.picture")
        let music = element(app, "editor.music")
        XCTAssertTrue(element(app, "editor.frames.1").exists)
        let before = picture.frame.height
        print("fold: before the fold the strip is \(region.frame.height) high, editor.picture \(before)")

        fold(app)
        assertFolded(app, textSelected: false)
        print("fold: folded editor.clip.1 is \(blue.frame.height) high, editor.music at y \(music.frame.minY - region.frame.minY)")
        XCTAssertEqual(music.frame.minY - region.frame.minY, 68, accuracy: 1)
        waitUntil("editor.picture 32 points higher after the fold") { abs(picture.frame.height - before - 32) <= 2 }
        print("fold: folded editor.picture is \(picture.frame.height) high, \(picture.frame.height - before) more")
        XCTAssertEqual(picture.frame.height - before, 32, accuracy: 2)
        screenshot("fold-01-folded")

        element(app, "editor.frames").tap()
        waitUntil("a strip 128 high with blocks of 56 after the second tap") {
            abs(region.frame.height - 128) <= 1 && abs(blue.frame.height - 56) <= 1
        }
        print("fold: unfolded the strip is \(region.frame.height) high, editor.clip.1 \(blue.frame.height)")
        XCTAssertEqual(region.frame.height, 128, accuracy: 1)
        XCTAssertEqual(blue.frame.height, 56, accuracy: 1)
        XCTAssertTrue(element(app, "editor.frames.1").exists)
        // The fold is no step of undo.
        XCTAssertFalse(element(app, "editor.undo").isEnabled)

        // The fold is not kept: the reopened draft shows its blocks unfolded.
        fold(app)
        app.terminate()
        app = startApp(seed: nil, drafts: "kept")
        waitUntil("drafts.row.1 on the start screen", expected: 10, limit: 30) {
            self.element(app, "drafts.row.1").exists
        }
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        let reopened = element(app, "editor.clip.1")
        print("fold: in the reopened draft the strip is \(element(app, "editor.timelineRegion").frame.height) high, editor.clip.1 \(reopened.frame.height)")
        XCTAssertEqual(element(app, "editor.timelineRegion").frame.height, 128, accuracy: 1)
        XCTAssertEqual(reopened.frame.height, 56, accuracy: 1)
        XCTAssertTrue(element(app, "editor.frames.1").exists)
    }

    func testFoldedTheEndHandleOfBlueTrimsIt() {
        let app = startFold(seed: "two-clips-wide", playhead: 1800)
        fold(app)
        assertFolded(app, textSelected: false)
        let blue = element(app, "editor.clip.1")
        let end = element(app, "editor.trim.end")
        blue.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("blue selected with its end handle after the tap on it") { blue.isSelected && end.exists }
        print("fold: the end handle of blue at \(end.frame)")
        XCTAssertEqual(end.frame.height, 24, accuracy: 1)

        let start = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -60, dy: 0)))
        waitUntil("blue shorter than 1800 ticks after the drag of its end handle") {
            self.length(of: self.value(app, 1)) < 1800
        }
        print("fold: after the drag of the end handle editor.clip.1 reads " + value(app, 1))
        XCTAssertTrue(value(app, 1).hasPrefix("blue 0+"), value(app, 1))
        XCTAssertEqual(value(app, 2), "red 0+2400 100 v")
    }

    func testFoldedTheWalkOfE20MovesGreen() {
        let app = startFold(seed: "three-clips", playhead: 3300)
        fold(app)
        assertFolded(app, textSelected: false)
        let greenBlock = element(app, "editor.clip.3")
        let redBlock = element(app, "editor.clip.2")
        print("fold: editor.clip.3 at the press \(greenBlock.frame), editor.clip.2 \(redBlock.frame)")
        let from = greenBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = redBlock.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 4, dy: 0))
        from.press(forDuration: 0.6, thenDragTo: to)
        waitUntil("editor.clip.2 reading green after the press and drag", expected: 1, limit: 10) {
            self.value(app, 2) == "green 0+1200 100 v"
        }
        let values = [value(app, 1), value(app, 2), value(app, 3)]
        print("fold: after the press and drag the blocks read \(values)")
        XCTAssertEqual(values, ["blue 0+1800 100 v", "green 0+1200 100 v", "red 0+2400 100 v"])
    }

    func testFoldedTheTextBarStandsAtY40OfAStrip72High() {
        let app = startFold(seed: "text-box-wide")
        fold(app)
        assertFolded(app, textSelected: true)
        let region = element(app, "editor.timelineRegion")
        let bar = element(app, "editor.text.1")
        print("fold: folded editor.text.1 at y \(bar.frame.minY - region.frame.minY), \(bar.frame.height) high")
        XCTAssertEqual(bar.frame.minY - region.frame.minY, 40, accuracy: 1)
        XCTAssertEqual(bar.frame.height, 24, accuracy: 1)
    }

    /// Taps `editor.frames` and waits for blocks of 24 points.
    private func fold(_ app: XCUIApplication) {
        let blue = element(app, "editor.clip.1")
        element(app, "editor.frames").tap()
        waitUntil("editor.clip.1 24 high after the tap on editor.frames") { abs(blue.frame.height - 24) <= 1 }
    }

    /// The strip 96 high, or 72 with a selected text, blocks of 24 from y 8 and no tiles.
    private func assertFolded(_ app: XCUIApplication, textSelected: Bool) {
        let region = element(app, "editor.timelineRegion")
        let blue = element(app, "editor.clip.1")
        print("fold: folded the strip is \(region.frame.height) high, editor.clip.1 \(blue.frame.height) at y \(blue.frame.minY - region.frame.minY)")
        XCTAssertEqual(region.frame.height, textSelected ? 72 : 96, accuracy: 1)
        XCTAssertEqual(blue.frame.height, 24, accuracy: 1)
        XCTAssertEqual(blue.frame.minY - region.frame.minY, 8, accuracy: 1)
        XCTAssertFalse(element(app, "editor.frames.1").exists)
    }

    /// Starts the app with fresh drafts and waits for the editor: the first seeded start in a fresh simulator writes
    /// the clips first.
    private func startFold(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead, drafts: "fresh")
        waitForTheEditor(app)
        return app
    }

    /// Reads until the condition holds, for the effect of a tap, a drag or a launch. It is expected within the
    /// seconds given and fails only above the limit, which counts from the end of the first read.
    private func waitUntil(_ what: String, expected: Double = 1, limit: Double = 3, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        let first = waited
        while !holds && waited <= first + limit {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("fold: waited \(waited) seconds for \(what), expected \(expected), limit \(limit)")
        XCTAssertTrue(holds, what)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The value of the block at the position, empty when there is none.
    private func value(_ app: XCUIApplication, _ position: Int) -> String {
        element(app, "editor.clip." + String(position)).value as? String ?? ""
    }

    /// The length in ticks of a value "<media> <start>+<length> <volume> <v or p>", Int.max when it reads none.
    private func length(of value: String) -> Int {
        let fields = value.split(separator: " ")
        guard fields.count > 1, let plus = fields[1].split(separator: "+").last else {
            return Int.max
        }
        return Int(plus) ?? Int.max
    }
}
