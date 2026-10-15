import XCTest

// The volume of a clip at its highest, 200 percent, on `two-clips-wide`. At 4 seconds red is from x 141 to 381, at
// 60 points a second with the playhead at x 201. A clip is read by the value of its block, "<media> <start>+<duration>
// <volume times 100> <v or p>", and the sound of the project from `editor.soundInfo`, whose first field is the volume
// of all clips times 100 and the second "." while not muted.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class ClipGainTests: XCTestCase {
    /// The most drags toward the higher end the test makes before the volume of the clip must read 200.
    private let mostMoves = 5

    /// Half the width of the thumb: the track runs from this far inside one end of the slider to as far inside the
    /// other.
    private let thumbHalf: CGFloat = 14

    /// A scripted move does not reach the higher end of a mirrored slider, so the thumb is dragged by coordinates,
    /// from where the value puts it to past the higher end: the right end, the left one in Arabic, where the slider
    /// mirrors. The drags are repeated until the value of red ends " 200 v".
    func testRedAtItsHighestReadsTwoHundredAndTheClipsStayAtOneHundred() {
        for language in ["en", "ar", "sv"] {
            let app = startApp(seed: "two-clips-wide", language: language, playhead: 2400, drafts: "fresh")
            waitForTheEditor(app)
            let red = element(app, "editor.clip.2")
            red.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            waitUntil("editor.clip.2 selected and editor.clipRegion in " + language) {
                red.isSelected && self.element(app, "editor.clipRegion").exists
            }
            let slider = app.sliders["clip.volume"]
            waitUntil("the slider clip.volume in " + language) { slider.exists }
            let mirrored = language == "ar"
            let width = slider.frame.width
            let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            let highest = start.withOffset(CGVector(dx: mirrored ? -30 : width + 30, dy: 0))
            print("clip-gain: in " + language + " the slider at \(slider.frame), mirrored \(mirrored), the highest end at \(highest.screenPoint)")
            var moves = 0
            while !value(app, "editor.clip.2").hasSuffix(" 200 v") && moves < mostMoves {
                let before = value(app, "editor.clip.2")
                // The share of the range the value stands at, from the end of 0 along the track.
                let share = CGFloat(max(volume(before), 0)) / 200
                let along = thumbHalf + (width - 2 * thumbHalf) * share
                let thumb = start.withOffset(CGVector(dx: mirrored ? width - along : along, dy: 0))
                thumb.press(forDuration: 0.05, thenDragTo: highest)
                moves += 1
                // A drag that misses the thumb changes nothing, so this wait does not fail: the last assert on
                // " 200 v" decides.
                waitUntil(
                    "a value of editor.clip.2 other than " + before + " after drag \(moves) in " + language,
                    failing: false
                ) {
                    self.value(app, "editor.clip.2") != before
                }
                print("clip-gain: in " + language + " after drag \(moves) from \(thumb.screenPoint) editor.clip.2 reads " + value(app, "editor.clip.2"))
            }
            XCTAssertTrue(value(app, "editor.clip.2").hasSuffix(" 200 v"), value(app, "editor.clip.2"))
            let sound = app.staticTexts["editor.soundInfo"].label
            print("clip-gain: in " + language + " editor.soundInfo reads " + sound)
            XCTAssertTrue(sound.hasPrefix("100 ."), sound)
            screenshot(language == "en" ? "clip-gain-01-highest" : "clip-gain-01-highest-" + language)
            app.terminate()
        }
    }

    /// The volume field of a block's value, -1 when it cannot be read.
    private func volume(_ value: String) -> Int {
        let fields = value.split(separator: " ")
        return fields.count > 2 ? Int(fields[2]) ?? -1 : -1
    }

    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        element(app, identifier).value as? String ?? ""
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds. With `failing` false it only waits.
    private func waitUntil(_ what: String, expected: Double = 1, failing: Bool = true, _ reached: () -> Bool) {
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
        print("clip-gain: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if failing {
            XCTAssertTrue(holds, what)
        }
    }
}
