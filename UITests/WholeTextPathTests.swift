import XCTest

// The whole path with a text in one test, on the seed two-clips-wide (blue 3 seconds, then red 4, the
// landscape canvas, no text): add, type, done, style, move, set the length, play, export, delete and a
// relaunch. Then her look on the seed text-wide, and the three parts of the text panel in Arabic and in
// Swedish. The screen is 402 points wide with the playhead at x 201, the scale is 60 points a second, and
// a handle of a bar is 24 points wide outside its edge. The values of the selected text are read from
// `editor.textInfo` by the place of a field, counted from 1: position, font, size, colour, alignment,
// centre, rotation, marks, range, line spacing. Its string is read as the value of `text.field`, what a
// bar shows as the value of the bar, and the picture through the probe `share(of:in:)`. On the blue clip
// the letters and the box are the only pixels that are not blue.
//
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xctest/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/tap()
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/sliders
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/keyboards
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/textviews
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholeTextPathTests: XCTestCase {
    private let white = (r: 255, g: 255, b: 255)
    private let blue = (r: 0, g: 0, b: 255)
    private let red = (r: 255, g: 0, b: 0)

    /// T: with a white text in the picture the share of white is more than this, with none or with a text
    /// in another colour it is less. Neither clip has a white pixel.
    private let leastWhite = 0.00001
    /// With the picture alone in its area and a few white lines of size 64 on the blue clip, the share of
    /// blue is more than this. The lines take about 0.003 of the picture.
    private let blueUnderLines = 0.98

    private let newText = "1 naskh 64 255,255,255 centre 960,540 0 ... 0+4200 0"
    private let parts = ["text.tab.type", "text.tab.look", "text.tab.more", "text.done"]

    /// The start of the walk and of its step, for the printed times.
    private var walkBegan = Date()
    private var stepBegan = Date()

    func testTheWholePathWithATextFromTheButtonToASavedVideo() {
        mark("text-path-01-path")
        walkBegan = Date()
        stepBegan = walkBegan
        var app = startText(seed: "two-clips-wide")
        let picture = element(app, "editor.picture")
        let bar = element(app, "editor.text.1")

        // The editor: blue fills the picture, nothing is selected and the strip has no bar.
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue with no text", in: picture, moreThan: 0.9), 0.9, "blue")
        print("text-path: with no text the share of white is \(share(of: white, in: picture)), T \(leastWhite)")
        XCTAssertEqual(textInfo(app), "none")
        XCTAssertEqual(app.staticTexts["editor.faceInfo"].label, "Amiri-Regular Amiri-Bold")
        XCTAssertFalse(bar.exists)
        XCTAssertTrue(element(app, "editor.addText").isEnabled)
        screenshot("text-path-01-editor")
        stepDone("the editor")

        // Add and type, in Latin letters only.
        let typed = app.descendants(matching: .any)["text.field"]
        element(app, "editor.addText").tap()
        waitUntil("the text region and the field after the tap on the text button, every button in its row") {
            element(app, "editor.textRegion").exists && typed.exists
                && inOneRow(app, ["editor.split", "editor.delete", "editor.addText"]) && inOneRow(app, parts)
        }
        typed.tap()
        // A keyboard that does not come fails nothing here: the typing fails by itself with no focus.
        waitUntil("the keyboard after the tap on the field", expected: 2, required: false) {
            app.keyboards.firstMatch.exists
        }
        typed.typeText("Peace\nbe upon you")
        waitUntil("both typed lines as the value of the field") { typed.value as? String == "Peace\nbe upon you" }
        XCTAssertEqual(textInfo(app), newText)
        screenshot("text-path-02-typed")
        stepDone("add and type")

        // Done: the text is on the picture and on the strip, and nothing is selected.
        tapDone(app)
        let whiteTyped = lowestShareOfWhite(in: picture, "after done")
        XCTAssertGreaterThan(whiteTyped, leastWhite, "white of the typed lines")
        XCTAssertTrue(bar.exists)
        guard bar.exists else {
            return
        }
        XCTAssertEqual(
            bar.frame.width, element(app, "editor.clip.1").frame.width + element(app, "editor.clip.2").frame.width,
            accuracy: 1)
        XCTAssertEqual(shown(on: bar), "Peace")
        XCTAssertEqual(textInfo(app), "none")
        let blueBefore = share(of: blue, in: picture)
        print("text-path: before the style the share of blue is \(blueBefore) and the share of white \(whiteTyped)")
        screenshot("text-path-03-on-picture")
        stepDone("on the picture and on the strip")

        // The style. A tap in the upper left corner of the picture, away from the letters, selects the text.
        picture.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12)).tap()
        waitUntil("the text selected after the tap on the picture, the panel on the part look in its row") {
            field(app, 1) == "1" && element(app, "editor.textRegion").exists
                && element(app, "text.tab.look").isSelected && inOneRow(app, parts)
        }
        element(app, "text.font.naskh-bold").tap()
        waitUntil("field 2 naskh-bold after the tap on that face") { field(app, 2) == "naskh-bold" }
        element(app, "text.colour.3").tap()
        waitUntil("field 4 255,214,10 after the tap on text.colour.3") { field(app, 4) == "255,214,10" }
        // The move of a slider does not promise the place it lands on, so only the direction is asserted.
        let slider = app.descendants(matching: .any)["text.size"]
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)))
        waitUntil("field 3 above 64 after the move of text.size toward its upper end") {
            (Int(field(app, 3)) ?? 0) > 64
        }
        print("text-path: field 3 after the move of text.size toward its upper end \(field(app, 3))")
        element(app, "text.tab.more").tap()
        waitUntil("text.box after the tap on text.tab.more") { element(app, "text.box").exists }
        element(app, "text.box").tap()
        waitUntil("field 8 ..b after the tap on text.box") { field(app, 8) == "..b" }
        XCTAssertEqual(field(app, 2), "naskh-bold")
        XCTAssertGreaterThan(Int(field(app, 3)) ?? 0, 64)
        XCTAssertEqual(field(app, 4), "255,214,10")
        let blueStyled = waitForTheShare(of: blue, "blue with the styled text", in: picture, lessThan: blueBefore)
        XCTAssertLessThan(blueStyled, blueBefore, "blue with the styled text")
        let whiteStyled = waitForTheShare(of: white, "white with the yellow text", in: picture, lessThan: leastWhite)
        XCTAssertLessThan(whiteStyled, leastWhite, "white with the yellow text")
        screenshot("text-path-04-styled")
        stepDone("the style")

        // The move: one finger from the upper left of the picture, 40 points down.
        let finger = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.15))
        finger.press(forDuration: 0.1, thenDragTo: finger.withOffset(CGVector(dx: 0, dy: 40)))
        waitUntil("a centre under 540 after the drag of 40 points down") { centreY(app) > 540 }
        print("text-path: field 6 after the drag of 40 points down reads \(field(app, 6))")
        let blueMoved = waitForTheShare(of: blue, "blue with the moved text", in: picture, lessThan: blueBefore)
        XCTAssertLessThan(blueMoved, blueBefore, "blue with the moved text")
        screenshot("text-path-05-moved")
        stepDone("the move")

        // The length. At the start the end handle of the bar is right of the screen, from x 621. A scrub of
        // 310 points in the clip row moves the strip about 300, to 5 seconds, and the handle to x 321.
        let end = element(app, "editor.textTrim.end")
        scrub(app, fromX: 0.9, byPoints: -310)
        waitUntil("the end handle of the bar with 120 points of screen to its left after the scrub") {
            end.exists && end.frame.midX > 130 && end.frame.midX < 390
        }
        let handle = end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: -120, dy: 0)))
        waitUntil("a length below 4200 after the drag of the end handle") { (range(app)?.length ?? 4200) < 4200 }
        XCTAssertEqual(range(app)?.start, 0)
        XCTAssertGreaterThanOrEqual(range(app)?.length ?? 0, 60)
        print("text-path: field 9 after the drag of the end handle 120 points to the left reads \(field(app, 9))")

        // The empty part of the text row, right of the end handle: nothing is selected then.
        let strip = element(app, "editor.timelineRegion")
        let empty = CGVector(dx: (end.frame.maxX + strip.frame.maxX) / 2, dy: bar.frame.midY)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(empty).tap()
        waitUntil(
            "no selected text after the tap on the empty part of the text row, the picture as wide as its region",
            expected: 2
        ) {
            textInfo(app) == "none" && !element(app, "editor.textRegion").exists && pictureIsWide(app)
        }
        XCTAssertTrue(bar.exists)

        // To the end of the strip, past the end of the text: red between its black bars.
        for _ in 0..<2 {
            scrub(app, fromX: 0.9, byPoints: -320)
        }
        waitUntil("the playhead at the end of the strip") { theTwoSidesAreTheSame(app) }
        let redAtTheEnd = waitForTheShare(of: red, "red at the end of the strip", in: picture, moreThan: 0.2)
        let blueAtTheEnd = share(of: blue, in: picture)
        print("text-path: at the end of the strip the share of red is \(redAtTheEnd) and the share of blue \(blueAtTheEnd)")
        XCTAssertGreaterThan(redAtTheEnd, 0.2, "red at the end of the strip")
        XCTAssertLessThan(blueAtTheEnd, 0.05, "blue at the end of the strip")
        screenshot("text-path-06-past-the-end")

        // Back to the start. The red frame has no blue, so the share is waited for above half of what the
        // moved text left, which only the blue frame gives, and below what it was before the style.
        scrubToTheStart(app)
        let blueBack = waitForTheShare(
            of: blue, "blue with the text at 00:00 again", in: picture, moreThan: blueMoved / 2, lessThan: blueBefore)
        XCTAssertGreaterThan(blueBack, blueMoved / 2, "the blue frame at 00:00 again")
        XCTAssertLessThan(blueBack, blueBefore, "blue with the text at 00:00 again")
        stepDone("the length")

        // The playback from 00:00 to the end, 7 seconds.
        mark("text-path-02-plays")
        element(app, "editor.play").tap()
        waitUntil("the same time on both sides of the slash at the end of the playback", expected: 8) {
            theTwoSidesAreTheSame(app)
        }
        stepDone("the playback")

        // The export. The simulator run grants the right to add to Photos, so no question is expected.
        element(app, "editor.export").tap()
        let done = element(app, "export.done")
        waitUntil("export.done after the export", expected: 30) { done.exists }
        screenshot("text-path-07-saved")
        done.tap()
        waitUntil("the saved panel gone after the tap on export.done") { !done.exists }
        stepDone("the export")

        // The delete. At 00:00 the bar begins at the playhead line, so a quarter of its width is on the screen.
        scrubToTheStart(app)
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the text selected after the tap on its bar") { bar.isSelected && field(app, 1) == "1" }
        element(app, "editor.delete").tap()
        waitUntil(
            "no bar and no selected text after the tap on delete, the picture as wide as its region", expected: 2
        ) {
            !bar.exists && textInfo(app) == "none" && !element(app, "editor.textRegion").exists
                && pictureIsWide(app)
        }
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertTrue(element(app, "editor.clip.2").exists)
        XCTAssertEqual(playheadValue(app), "00:00")
        // More than 0.9, and more than the boxed text left of it, so a text that is still drawn is not passed.
        let blueDeleted = waitForTheShare(
            of: blue, "blue after the delete", in: picture, moreThan: max(0.9, blueBack))
        print("text-path: the share of blue with the text \(blueBack) and after the delete \(blueDeleted)")
        XCTAssertGreaterThan(blueDeleted, 0.9, "blue after the delete")
        XCTAssertGreaterThan(blueDeleted, blueBack, "blue after the delete against blue with the text")
        screenshot("text-path-08-deleted")
        stepDone("the delete")

        // The relaunch: nothing of the text and no project to reopen.
        app.terminate()
        app = startApp(seed: nil)
        waitUntil("the start screen after the relaunch with no seed", expected: 20) {
            element(app, "start.newProject").exists
        }
        XCTAssertTrue(element(app, "start.title").exists)
        XCTAssertFalse(element(app, "editor.root").exists)
        XCTAssertFalse(element(app, "editor.text.1").exists)
        screenshot("text-path-09-relaunch")
        stepDone("the relaunch")
        print("text-path: walk finished, \(Date().timeIntervalSince(walkBegan)) seconds")
    }

    /// The text of the seed over the blue clip and over the red clip, selected with the panel on the part
    /// look, and then after done. The Arabic line is read on the three pictures.
    func testHerLookOverBlueOverRedAndAfterDone() {
        var app = startText(seed: "text-wide", playhead: 600)
        var picture = element(app, "editor.picture")
        waitUntil("the part row of the panel after the start") { inOneRow(app, parts) }
        XCTAssertEqual(field(app, 1), "1")
        XCTAssertTrue(element(app, "text.tab.look").isSelected)
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white over blue", in: picture, moreThan: leastWhite), leastWhite,
            "white over blue")
        screenshot("text-path-10-her-look")

        // Five seconds: red stands in the middle between black bars, under the same text.
        app = startText(seed: "text-wide", playhead: 3000)
        picture = element(app, "editor.picture")
        waitUntil("the part row of the panel after the start at 3000") { inOneRow(app, parts) }
        XCTAssertGreaterThan(waitForTheShare(of: red, "red", in: picture, moreThan: 0.2), 0.2, "red")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white over red", in: picture, moreThan: leastWhite), leastWhite,
            "white over red")
        screenshot("text-path-11-her-look-red")

        tapDone(app)
        XCTAssertFalse(element(app, "editor.textRegion").exists)
        XCTAssertTrue(element(app, "editor.text.1").exists)
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white over red after done", in: picture, moreThan: leastWhite), leastWhite,
            "white over red after done")
        screenshot("text-path-12-her-look-done")
    }

    func testInArabicTheThreePartsOfThePanelMirrorWhereTheyShould() {
        assertTheThreeParts(language: "ar", mirrored: true)
    }

    func testInSwedishTheThreePartsOfThePanelShow() {
        assertTheThreeParts(language: "sv", mirrored: false)
    }

    /// The parts type, look and more of the panel on text-wide at one second. The tools row and the panel
    /// follow the language. The picture, the strip, the bar, its handle and the three sides never mirror.
    /// At one second the bar is from x 141 to 561, so its start handle is on the screen and its end handle
    /// is not, and only the start handle is read.
    private func assertTheThreeParts(language: String, mirrored: Bool) {
        let app = startText(seed: "text-wide", language: language, playhead: 600)
        let picture = element(app, "editor.picture")
        let typeTab = element(app, "text.tab.type")
        let lookTab = element(app, "text.tab.look")
        let moreTab = element(app, "text.tab.more")
        waitUntil("the part row of the panel after the start") { inOneRow(app, parts) }
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")

        typeTab.tap()
        waitUntil("the field after the tap on text.tab.type, the part button selected and in its row") {
            app.descendants(matching: .any)["text.field"].exists && typeTab.isSelected && inOneRow(app, parts)
        }
        // Leading is the right in Arabic: split and the part type stand at the right end of their rows,
        // and done at the left end of its row.
        XCTAssertEqual(
            element(app, "editor.split").frame.minX > element(app, "editor.delete").frame.minX, mirrored)
        XCTAssertEqual(typeTab.frame.minX > lookTab.frame.minX, mirrored)
        XCTAssertEqual(lookTab.frame.minX > moreTab.frame.minX, mirrored)
        XCTAssertEqual(element(app, "text.done").frame.minX < moreTab.frame.minX, mirrored)
        // Fixed left to right in every language.
        let bar = element(app, "editor.text.1")
        let first = element(app, "editor.clip.1")
        XCTAssertLessThan(element(app, "editor.play").frame.minX, element(app, "editor.time").frame.minX)
        XCTAssertEqual(picture.frame.midX, element(app, "editor.previewRegion").frame.midX, accuracy: 1)
        XCTAssertLessThan(first.frame.minX, element(app, "editor.clip.2").frame.minX)
        XCTAssertEqual(bar.frame.minX, first.frame.minX, accuracy: 1)
        XCTAssertEqual(element(app, "editor.textTrim.start").frame.maxX, bar.frame.minX, accuracy: 1)
        takeThePicture("text-path-13-type-" + language, of: picture)

        lookTab.tap()
        let naskh = element(app, "text.font.naskh")
        waitUntil("the first face after the tap on text.tab.look, the part button selected and in its row") {
            naskh.exists && lookTab.isSelected && inOneRow(app, parts)
        }
        XCTAssertEqual(naskh.frame.minX > element(app, "text.font.naskh-bold").frame.minX, mirrored)
        XCTAssertEqual(
            element(app, "text.colour.1").frame.minX > element(app, "text.colour.8").frame.minX, mirrored)
        takeThePicture("text-path-14-look-" + language, of: picture)

        moreTab.tap()
        let left = element(app, "text.align.left")
        let centre = element(app, "text.align.centre")
        waitUntil("the first side after the tap on text.tab.more, the part button selected and in its row") {
            left.exists && moreTab.isSelected && inOneRow(app, parts)
        }
        // The sides are sides of the picture, so their row does not mirror. The toggles do.
        XCTAssertLessThan(left.frame.minX, centre.frame.minX)
        XCTAssertLessThan(centre.frame.minX, element(app, "text.align.right").frame.minX)
        XCTAssertEqual(
            element(app, "text.outline").frame.minX > element(app, "text.shadow").frame.minX, mirrored)
        XCTAssertEqual(element(app, "text.shadow").frame.minX > element(app, "text.box").frame.minX, mirrored)
        takeThePicture("text-path-15-more-" + language, of: picture)
    }

    /// A part of another height changes the size of the picture area, so a picture of the screen is taken
    /// when the white lines of the seed are read in the area as it then is.
    private func takeThePicture(_ name: String, of picture: XCUIElement) {
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white of the lines for " + name, in: picture, moreThan: leastWhite),
            leastWhite, "white of the lines for " + name)
        screenshot(name)
    }

    /// Prints the seconds of the step that ends here and the seconds since the start of the walk.
    private func stepDone(_ what: String) {
        let now = Date()
        print(
            "text-path: step \(what) took \(now.timeIntervalSince(stepBegan)) seconds, \(now.timeIntervalSince(walkBegan)) since the start of the walk"
        )
        stepBegan = now
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

    private func textInfo(_ app: XCUIApplication) -> String {
        app.staticTexts["editor.textInfo"].label
    }

    /// The field of `editor.textInfo` at the place, counted from 1, or nothing when there is none.
    private func field(_ app: XCUIApplication, _ place: Int) -> String {
        let fields = textInfo(app).split(separator: " ")
        return place <= fields.count ? String(fields[place - 1]) : ""
    }

    /// The y of field 6, the centre of the text in canvas pixels. A line with no centre gives -1.
    private func centreY(_ app: XCUIApplication) -> Int {
        let numbers = field(app, 6).split(separator: ",").compactMap { Int($0) }
        return numbers.count == 2 ? numbers[1] : -1
    }

    /// The ninth field as two numbers of ticks, or nil when it is no range.
    private func range(_ app: XCUIApplication) -> (start: Int, length: Int)? {
        let numbers = field(app, 9).split(separator: "+")
        guard numbers.count == 2, let start = Int(numbers[0]), let length = Int(numbers[1]) else {
            return nil
        }
        return (start, length)
    }

    /// What is written on a bar: its value. Its label is the word of the app for it.
    private func shown(on bar: XCUIElement) -> String {
        bar.value as? String ?? ""
    }

    private func playheadValue(_ app: XCUIApplication) -> String {
        element(app, "editor.playhead").value as? String ?? ""
    }

    /// True when `editor.time` reads the same time on both sides of its slash, as in "00:07 / 00:07".
    private func theTwoSidesAreTheSame(_ app: XCUIApplication) -> Bool {
        let sides = element(app, "editor.time").label.components(separatedBy: " / ")
        return sides.count == 2 && sides[0] == sides[1]
    }

    /// True when the picture is as wide as its region, as it is on the landscape canvas with no panel
    /// and no keyboard.
    private func pictureIsWide(_ app: XCUIApplication) -> Bool {
        abs(element(app, "editor.picture").frame.width - element(app, "editor.previewRegion").frame.width) <= 1
    }

    /// True when all the controls are there and their middles lie at one height, within 4 points.
    private func inOneRow(_ app: XCUIApplication, _ identifiers: [String]) -> Bool {
        let controls = identifiers.map { element(app, $0) }
        guard controls.allSatisfy({ $0.exists }) else {
            return false
        }
        let heights = controls.map { Double($0.frame.midY) }
        return (heights.max() ?? 0) - (heights.min() ?? 0) <= 4
    }

    /// Drags the strip sideways in the clip row, from a share of the width of the timeline region.
    /// Minus is to the left, which is later. The start must be a point where no handle lies.
    private func scrub(_ app: XCUIApplication, fromX: Double, byPoints points: Double) {
        let start = element(app, "editor.timelineRegion")
            .coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.35))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: points, dy: 0)))
    }

    /// Two drags of 320 points to the right from x 40, where no handle lies with nothing selected. The
    /// strip is 420 points long and each drag moves it about 310.
    private func scrubToTheStart(_ app: XCUIApplication) {
        for _ in 0..<2 {
            scrub(app, fromX: 0.1, byPoints: 320)
        }
        waitUntil("the playhead back at 00:00") { playheadValue(app) == "00:00" }
    }

    /// Taps done and waits until the text region and the keyboard are gone and the picture is as wide as
    /// its region again.
    private func tapDone(_ app: XCUIApplication) {
        element(app, "text.done").tap()
        waitUntil(
            "the text region and the keyboard gone after the tap on done, the picture as wide as its region",
            expected: 2
        ) {
            !element(app, "editor.textRegion").exists && !app.keyboards.firstMatch.exists && pictureIsWide(app)
        }
    }

    /// For the picture of the typed lines after done. Waits until the area is blue but for the lines, so
    /// the layout stands and nothing else lies in the area, then until the share of white is above T, and
    /// from then reads it as often as the probe can for one second. Answers the lowest of those reads: a
    /// white pixel of a control that only passes over the area is gone within that second.
    private func lowestShareOfWhite(in picture: XCUIElement, _ when: String) -> Double {
        let alone = waitForTheShare(
            of: blue, "blue with the picture alone in its area", in: picture, moreThan: blueUnderLines)
        XCTAssertGreaterThan(alone, blueUnderLines, "blue " + when)
        var lowest = waitForTheShare(of: white, "white " + when, in: picture, moreThan: leastWhite)
        let started = Date()
        var reads = 1
        repeat {
            lowest = min(lowest, share(of: white, in: picture))
            reads += 1
        } while Date().timeIntervalSince(started) < 1
        print("text-path: \(reads) reads of white in one second \(when), the lowest share \(lowest), T \(leastWhite)")
        return lowest
    }

    /// No element says when a frame is drawn, so the share is asked again until it is more than the one
    /// number and less than the other, whichever are given. Prints the seconds it waited, gives up only
    /// above three times the expected 3 seconds, and answers the last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement,
        moreThan least: Double = -1, lessThan most: Double = 2
    ) -> Double {
        let expected: Double = 3
        let started = Date()
        var waited: Double = 0
        var found = share(of: colour, in: picture)
        while !(found > least && found < most) && waited <= 3 * expected {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print(
            "text-path: waited \(waited) seconds for a share of \(what) above \(least) and below \(most), found \(found), expected \(expected), limit \(3 * expected)"
        )
        return found
    }

    /// Reads until the condition holds, for the effect of a tap, of typing, of a drag or of a start. It
    /// fails only above three times the expected seconds: a hosted runner under load can hold the app for seconds.
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
        print("text-path: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
