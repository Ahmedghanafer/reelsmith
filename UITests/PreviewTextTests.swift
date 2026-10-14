import XCTest

// The picture area with text, on the landscape seeds two-clips-wide (blue 3 seconds, then red 4, no text),
// text-wide (three white lines for the whole video) and text-box-wide (the word "BOX" in a box from 600 to
// 1500 ticks). The picture is read through the probe `share(of:in:)`, the count of the items the preview
// built as the value of `editor.picture`, and the position of the selected text as the first field of
// `editor.textInfo`. On the blue clip the letters and the box are the only pixels that are not blue.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/keyboards
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/textviews
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class PreviewTextTests: XCTestCase {
    private let white = (r: 255, g: 255, b: 255)
    private let blue = (r: 0, g: 0, b: 255)
    private let red = (r: 255, g: 0, b: 0)

    /// T: with a text in the picture the share of white is more than this, with none it is less. Neither
    /// clip has a white pixel, so with no text no read finds one. Two letters of size 64 fill well under
    /// a thousandth of the canvas, and the probe reads every sixteenth pixel.
    private let leastWhite = 0.00001
    /// B: the blue clip alone gives a share of blue above this, the blue clip under the box of
    /// text-box-wide a share below it. The box covers between 2 and 3 hundredths of the canvas.
    private let blueWithNoBox = 0.99

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The picture is read once the blue frame stands, then a text is added and two letters are typed, with
    /// no tap on play and no scrub. With the keyboard up the picture area is small, so its share is only
    /// printed there, and done is tapped before the read that is asserted. Done changes neither the project
    /// nor the playhead. The asserted share is the lowest of the reads of one second, so nothing that only
    /// passes over the area while the layout settles counts. The printed lines tell which step showed the letters.
    func testTwoTypedLettersShowInThePausedPictureWithNoNewItem() {
        let app = startText(seed: "two-clips-wide", playhead: 600)
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        let whiteBefore = share(of: white, in: picture)
        let buildsBefore = builds(picture)
        print("preview-text: before the text the share of white is \(whiteBefore), T \(leastWhite), editor.picture \(buildsBefore)")

        addATextAndType(app, "MM")
        let whiteSmall = waitForTheShare(
            of: white, "white with the keyboard up", in: picture, moreThan: leastWhite, expected: 2)
        print("preview-text: with the keyboard up the share of white is \(whiteSmall), editor.picture \(builds(picture))")

        tapDone(app)
        let whiteAfter = lowestShareOfWhite(in: picture, "after the typing")
        let buildsAfter = builds(picture)
        print(
            "preview-text: the share of white before \(whiteBefore) and after \(whiteAfter), T \(leastWhite), editor.picture before \(buildsBefore) and after \(buildsAfter)"
        )
        XCTAssertLessThan(whiteBefore, leastWhite, "white before the text")
        XCTAssertGreaterThan(whiteAfter, leastWhite, "white after the typing")
        // A whole number, and no item was built for the text.
        XCTAssertNotNil(Int(buildsBefore), "editor.picture has no count of builds")
        XCTAssertEqual(buildsAfter, buildsBefore, "an item was built for the text")
        screenshot("preview-text-01-follows-typing")
    }

    /// The text is added and typed as soon as the editor is there, with no wait for the picture, so the
    /// edit can fall into the build of the first item.
    func testLettersTypedAtOnceAfterAStartShowWhenThePictureHasCome() {
        let app = startText(seed: "two-clips-wide", playhead: 600)
        let picture = element(app, "editor.picture")

        addATextAndType(app, "MM")
        tapDone(app)
        let found = lowestShareOfWhite(in: picture, "typed at once after the start")
        print("preview-text: typed at once after the start, the share of white is \(found), editor.picture \(builds(picture))")
        XCTAssertGreaterThan(found, leastWhite, "white")
    }

    func testTheTextOfTheSeedStandsOverTheBlueClipAndOverTheRedClip() {
        var app = startText(seed: "text-wide", playhead: 600)
        var picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white", in: picture, moreThan: leastWhite), leastWhite, "white over blue")
        XCTAssertEqual(position(app), "1")
        screenshot("preview-text-02-her-look")

        // Five seconds: red stands in the middle between black bars, under the same text.
        app = startText(seed: "text-wide", playhead: 3000)
        picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: red, "red", in: picture, moreThan: 0.2), 0.2, "red")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white", in: picture, moreThan: leastWhite), leastWhite, "white over red")
        screenshot("preview-text-03-over-red")
    }

    /// The playhead value is past the length, so the editor starts at the very end, 7 of 7 seconds. The
    /// picture there is the last frame, red between black bars, and the text of the seed is in it.
    func testAtTheVeryEndOfTheProjectTheTextIsInThePicture() {
        let app = startText(seed: "text-wide", playhead: 7000)
        let picture = element(app, "editor.picture")
        XCTAssertEqual(element(app, "editor.time").label, "00:07 / 00:07")
        XCTAssertGreaterThan(waitForTheShare(of: red, "red", in: picture, moreThan: 0.2), 0.2, "red")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white at the end", in: picture, moreThan: leastWhite), leastWhite,
            "white at the end")
        screenshot("preview-text-05-at-the-end")
    }

    func testInArabicThePictureWithTextDoesNotMirror() {
        let app = startText(seed: "text-wide", language: "ar", playhead: 600)
        let picture = element(app, "editor.picture")

        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white", in: picture, moreThan: leastWhite), leastWhite, "white")
        // The same order from left to right as in English, and the picture in the middle of its region.
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertEqual(picture.frame.midX, element(app, "editor.previewRegion").frame.midX, accuracy: 1)
        screenshot("preview-text-02-her-look-ar")
    }

    /// The box lies over the blue clip from 600 to 1500 ticks: before it and after it the area is blue.
    func testTheBoxIsInThePictureOnlyInsideItsRange() {
        var app = startText(seed: "text-box-wide", playhead: 300)
        var picture = element(app, "editor.picture")
        XCTAssertGreaterThan(
            waitForTheShare(of: blue, "blue before the box", in: picture, moreThan: blueWithNoBox), blueWithNoBox,
            "blue before the box")

        // The frame has come when most of the area is blue, and the box is in that frame.
        app = startText(seed: "text-box-wide", playhead: 900)
        picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue around the box", in: picture, moreThan: 0.9), 0.9, "blue")
        let under = share(of: blue, in: picture)
        print("preview-text: the share of blue with the box is \(under), B \(blueWithNoBox)")
        XCTAssertLessThan(under, blueWithNoBox, "blue with the box")
        screenshot("preview-text-04-box")

        app = startText(seed: "text-box-wide", playhead: 1620)
        picture = element(app, "editor.picture")
        XCTAssertGreaterThan(
            waitForTheShare(of: blue, "blue after the box", in: picture, moreThan: blueWithNoBox), blueWithNoBox,
            "blue after the box")
    }

    /// The recording from the mark on shows the box come at about one second and go at about two and a
    /// half. Only the reports of the player move the time, and no time of the box is asserted.
    func testPlaybackFromZeroPassesTheRangeOfTheBox() {
        let app = startText(seed: "text-box-wide")
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")

        mark("preview-text-01-plays")
        element(app, "editor.play").tap()
        // "mm:ss" texts are in the order of their times.
        waitUntil("three seconds of the playback as the time before the slash", expected: 4) {
            (element(app, "editor.time").label.components(separatedBy: " / ").first ?? "") >= "00:03"
        }
    }

    func testASplitBuildsANewItemAndThePictureStays() {
        let app = startText(seed: "two-clips-wide", playhead: 600)
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        let before = builds(picture)
        XCTAssertNotNil(Int(before), "editor.picture has no count of builds")

        let split = element(app, "editor.split")
        XCTAssertTrue(split.isEnabled)
        split.tap()
        waitUntil("a higher count of builds after the split") {
            (Int(builds(picture)) ?? 0) > (Int(before) ?? Int.max)
        }
        print("preview-text: editor.picture before the split \(before) and after it \(builds(picture))")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue after the split", in: picture, moreThan: 0.9), 0.9, "blue")
    }

    /// Starts the app and waits for the editor: the first seeded start in a fresh simulator writes the clips first.
    private func startText(seed: String, language: String = "en", playhead: Int? = nil) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead)
        waitForTheEditor(app)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The value of `editor.picture`: the count of the items the preview built, or "none" with no value.
    private func builds(_ picture: XCUIElement) -> String {
        picture.value as? String ?? "none"
    }

    /// The first field of `editor.textInfo`: the position of the selected text, or "none".
    private func position(_ app: XCUIApplication) -> String {
        String(app.staticTexts["editor.textInfo"].label.split(separator: " ").first ?? "")
    }

    /// Taps the text button, then the field, and types. A keyboard that does not come is printed and fails
    /// nothing here: the typing fails by itself when the field has no focus.
    private func addATextAndType(_ app: XCUIApplication, _ string: String) {
        element(app, "editor.addText").tap()
        let field = app.textViews["text.field"]
        waitUntil("the field after the tap on the text button") { field.exists }
        field.tap()
        waitUntil("the keyboard after the tap on the field", expected: 2, required: false) {
            app.keyboards.firstMatch.exists
        }
        field.typeText(string)
        waitUntil("the typed letters as the value of the field") { field.value as? String == string }
    }

    /// Taps done and waits until the text region and the keyboard are gone and the picture is as wide as
    /// its region again, as it is on the landscape canvas with no panel and no keyboard.
    private func tapDone(_ app: XCUIApplication) {
        element(app, "text.done").tap()
        waitUntil(
            "the text region and the keyboard gone after the tap on done, the picture as wide as its region",
            expected: 2
        ) {
            !element(app, "editor.textRegion").exists && !app.keyboards.firstMatch.exists
                && abs(element(app, "editor.picture").frame.width - element(app, "editor.previewRegion").frame.width)
                    <= 1
        }
    }

    /// For the picture of two typed letters after done. Waits until the area is blue but for a hundredth,
    /// so the layout stands and nothing else lies in the area, then until the share of white is above T,
    /// and from then reads it as often as the probe can for one second. Answers the lowest of those
    /// reads: a white pixel of a control that only passes over the area is gone within that second.
    private func lowestShareOfWhite(in picture: XCUIElement, _ when: String) -> Double {
        let alone = waitForTheShare(
            of: blue, "blue with the picture alone in its area", in: picture, moreThan: blueWithNoBox)
        XCTAssertGreaterThan(alone, blueWithNoBox, "blue " + when)
        var lowest = waitForTheShare(of: white, "white " + when, in: picture, moreThan: leastWhite, expected: 2)
        let started = Date()
        var reads = 1
        repeat {
            lowest = min(lowest, share(of: white, in: picture))
            reads += 1
        } while Date().timeIntervalSince(started) < 1
        print("preview-text: \(reads) reads of white in one second \(when), the lowest share \(lowest), T \(leastWhite)")
        return lowest
    }

    /// No element says when a frame is drawn, so the share is asked again until it is more than wanted.
    /// Prints the seconds it waited, gives up only above three times the expected seconds, and answers
    /// the last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, moreThan wanted: Double,
        expected: Double? = nil
    ) -> Double {
        let expected = expected ?? expectedFrame
        let started = Date()
        var waited: Double = 0
        var found = share(of: colour, in: picture)
        while !(found > wanted) && waited <= 3 * expected {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print(
            "preview-text: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expected), limit \(3 * expected)"
        )
        return found
    }

    /// Reads until the condition holds, for the effect of a tap or of typing. It fails only above three
    /// times the expected seconds: a hosted runner under load can hold the app for seconds.
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
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("preview-text: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
