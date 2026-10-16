import XCTest

// Levels while playing, on the seed music-wide: the clips of two-clips-wide, blue 3 seconds and red 4 on the
// landscape canvas, under the long test tone, with the sound panel open at the start. A change of the music's start
// while the video plays still pauses and builds one item. The sound of the project is read from `editor.soundInfo`
// by the place of a field, counted from 1: field 3 is "<start>+<heard>" in ticks. The count of builds is the value
// of `editor.picture`. No test listens.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/sliders
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class LiveLevelsTests: XCTestCase {
    func testAChangeOfTheMusicStartWhilePlayingPausesAndBuildsOneItem() {
        let app = startApp(seed: "music-wide")
        waitForTheEditor(app)
        waitUntil("the part button sound.tab.levels after the start") { element(app, "sound.tab.levels").exists }
        element(app, "sound.tab.levels").tap()
        let slider = element(app, "sound.musicStart")
        waitUntil("the slider sound.musicStart after the tap on its part button") { slider.exists }
        let play = element(app, "editor.play")
        let picture = element(app, "editor.picture")
        let still = play.label
        play.tap()
        waitUntil("editor.play labelled otherwise than \(still) after the tap on it") { play.label != still }
        let before = builds(picture)
        let start = field(app, 3)
        XCTAssertNotNil(before, "editor.picture has no count of builds")

        slide(slider, to: 1)
        waitUntil("field 3 changed, editor.play labelled \(still) and a higher count of builds after the move") {
            field(app, 3) != start && play.label == still && (builds(picture) ?? 0) > (before ?? Int.max)
        }
        print("live-levels: after the move of sound.musicStart while playing editor.soundInfo reads \(soundInfo(app)), editor.play \(play.label), editor.picture \(builds(picture) ?? -1) from \(before ?? -1)")
        XCTAssertNotEqual(field(app, 3), start)
        XCTAssertEqual(play.label, still)
        XCTAssertEqual(builds(picture), (before ?? -2) + 1)
    }

    /// A Flutter slider reports as another kind and does not take adjust: a press at its middle dragged to the
    /// place moves it, as a finger does.
    private func slide(_ slider: XCUIElement, to place: CGFloat) {
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: place, dy: 0.5)))
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
