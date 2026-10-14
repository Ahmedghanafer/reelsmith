import XCTest

// The part more of the text panel, on the seed text-wide with the playhead at one second: three white lines
// over the blue clip on the landscape canvas, text 1 selected. Every start taps `text.tab.more`. The values
// of the text are read from `editor.textInfo` by the place of a field, counted from 1: position, font, size,
// colour, alignment, centre, rotation, marks, range, line spacing. The picture is read through the probe
// `share(of:in:)`. On the blue clip the letters and the box are the only pixels that are not blue.
//
// https://developer.apple.com/documentation/xctest/xcuielement/tap()
// https://developer.apple.com/documentation/xctest/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xctest/xcuielement/adjust(tonormalizedsliderposition:)
// https://developer.apple.com/documentation/xctest/xcuielement/normalizedsliderposition
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementattributes/label
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/sliders
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/keyboards
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider/textviews
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class TextMoreTests: XCTestCase {
    private let white = (r: 255, g: 255, b: 255)
    private let blue = (r: 0, g: 0, b: 255)

    /// B: with the three white lines alone over the blue clip the share of blue is more than this, and
    /// with the box behind them it is less. The lines take about 0.003 of the picture, the box of three
    /// lines at size 64 more than 0.03.
    private let blueWithNoBox = 0.98
    /// With the three white lines in the picture the share of white is more than this.
    private let whiteOfTheLines = 0.0005

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    private let sides = ["text.align.left", "text.align.centre", "text.align.right"]
    private let marks = ["text.outline", "text.shadow", "text.box"]

    func testThePartMoreShowsTheAlignmentTheSpacingAndTheMarksOfTheSelectedText() {
        let app = startMore()
        waitForThePicture(app)

        // Three sides in one row from left to right, with their English words.
        let sideButtons = sides.map { element(app, $0) }
        XCTAssertLessThan(sideButtons[0].frame.minX, sideButtons[1].frame.minX)
        XCTAssertLessThan(sideButtons[1].frame.minX, sideButtons[2].frame.minX)
        XCTAssertEqual(sideButtons.map { $0.label }, ["Left", "Centre", "Right"])
        // The slider under the sides, and the three toggles in one row under the slider.
        let slider = app.sliders["text.spacing"]
        XCTAssertTrue(slider.exists)
        XCTAssertGreaterThanOrEqual(slider.frame.minY, sideButtons[0].frame.maxY - 1)
        let toggles = marks.map { element(app, $0) }
        for index in 0...2 {
            XCTAssertTrue(toggles[index].exists, marks[index])
            XCTAssertGreaterThanOrEqual(toggles[index].frame.minY, slider.frame.maxY - 1, marks[index])
        }
        XCTAssertLessThan(toggles[0].frame.minX, toggles[1].frame.minX)
        XCTAssertLessThan(toggles[1].frame.minX, toggles[2].frame.minX)

        // The controls show the text of the seed: the centre, no mark, no line spacing.
        XCTAssertFalse(sideButtons[0].isSelected)
        XCTAssertTrue(sideButtons[1].isSelected)
        XCTAssertFalse(sideButtons[2].isSelected)
        for index in 0...2 {
            XCTAssertFalse(toggles[index].isSelected, marks[index])
        }
        XCTAssertEqual(field(app, 5), "centre")
        XCTAssertEqual(field(app, 8), "...")
        XCTAssertEqual(field(app, 10), "0")
        screenshot("text-more-01-more")
    }

    func testATapOnASideSetsTheAlignmentAndMovesTheTraitSelected() {
        let app = startMore()
        let left = element(app, "text.align.left")
        let centre = element(app, "text.align.centre")
        let right = element(app, "text.align.right")

        left.tap()
        waitUntil("field 5 left and that button alone selected after the tap on it") {
            field(app, 5) == "left" && left.isSelected && !centre.isSelected && !right.isSelected
        }
        right.tap()
        waitUntil("field 5 right and that button alone selected after the tap on it") {
            field(app, 5) == "right" && right.isSelected && !left.isSelected && !centre.isSelected
        }
    }

    /// The sides are sides of the picture, so their row does not mirror. The toggles do.
    func testInArabicTheSidesStayLeftToRightAndTheRestOfThePartMirrors() {
        let app = startMore(language: "ar")
        waitForThePicture(app)
        let left = element(app, "text.align.left")
        let centre = element(app, "text.align.centre")
        let right = element(app, "text.align.right")

        XCTAssertLessThan(left.frame.minX, centre.frame.minX)
        XCTAssertLessThan(centre.frame.minX, right.frame.minX)
        // Leading is the right now: the first toggle stands at the right end of its row.
        XCTAssertGreaterThan(element(app, "text.outline").frame.minX, element(app, "text.shadow").frame.minX)
        XCTAssertGreaterThan(element(app, "text.shadow").frame.minX, element(app, "text.box").frame.minX)
        XCTAssertTrue(centre.isSelected)
        screenshot("text-more-01-more-ar")

        left.tap()
        waitUntil("field 5 left and that button alone selected after the tap on it in Arabic") {
            field(app, 5) == "left" && left.isSelected && !centre.isSelected && !right.isSelected
        }
    }

    func testATapOnAToggleTurnsItsMarkOnAndASecondTapTurnsItOff() {
        let app = startMore()
        let outline = element(app, "text.outline")
        let shadow = element(app, "text.shadow")
        let box = element(app, "text.box")

        outline.tap()
        waitUntil("field 8 o.. and the outline alone selected after the tap on it") {
            field(app, 8) == "o.." && outline.isSelected && !shadow.isSelected && !box.isSelected
        }
        shadow.tap()
        waitUntil("field 8 os. and the outline and the shadow selected after the tap on the shadow") {
            field(app, 8) == "os." && outline.isSelected && shadow.isSelected && !box.isSelected
        }
        box.tap()
        waitUntil("field 8 osb and all three selected after the tap on the box") {
            field(app, 8) == "osb" && outline.isSelected && shadow.isSelected && box.isSelected
        }
        outline.tap()
        waitUntil("field 8 .sb and the outline not selected after the second tap on it") {
            field(app, 8) == ".sb" && !outline.isSelected && shadow.isSelected && box.isSelected
        }
    }

    /// With no tap on play and no scrub: the paused picture follows the box by itself.
    func testThePictureFollowsTheBox() {
        let app = startMore()
        let picture = element(app, "editor.picture")
        waitForThePicture(app)
        let before = share(of: blue, in: picture)
        print("text-more: before the tap on text.box the share of blue is \(before), B \(blueWithNoBox)")
        XCTAssertGreaterThan(before, blueWithNoBox, "blue before the tap")

        element(app, "text.box").tap()
        let after = waitForTheShare(of: blue, "blue after the tap on text.box", in: picture, lessThan: blueWithNoBox)
        print("text-more: after the tap on text.box the share of blue is \(after), B \(blueWithNoBox)")
        XCTAssertLessThan(after, blueWithNoBox, "blue after the tap")
        XCTAssertEqual(field(app, 8), "..b")
        screenshot("text-more-02-box")
    }

    /// The slider is moved with `adjust(toNormalizedSliderPosition:)`, which does not promise the place it
    /// lands on, so only the direction of each change is asserted. Field 10 is printed around each move.
    /// The box is turned on first, so the probe sees the lines move apart: the box grows with its block,
    /// and the picture of the spaced lines is taken when the share of blue has fallen again.
    func testTheSliderMovesTheLinesApartAndThenBackTogether() {
        let app = startMore()
        let picture = element(app, "editor.picture")
        let slider = app.sliders["text.spacing"]
        XCTAssertTrue(slider.exists)
        waitForThePicture(app)
        element(app, "text.box").tap()
        let boxed = waitForTheShare(of: blue, "blue with the box", in: picture, lessThan: blueWithNoBox)
        XCTAssertLessThan(boxed, blueWithNoBox, "blue with the box")
        XCTAssertEqual(field(app, 10), "0")
        print("text-more: field 10 before the first move \(field(app, 10)), the slider at \(slider.normalizedSliderPosition)")

        slider.adjust(toNormalizedSliderPosition: 0.8)
        waitUntil("field 10 above 0 after the move toward the upper end") { (spacing(app) ?? 0) > 0 }
        let wide = spacing(app) ?? 0
        print("text-more: field 10 after the move toward the upper end \(wide), the slider at \(slider.normalizedSliderPosition)")
        XCTAssertGreaterThan(wide, 0)
        let spaced = waitForTheShare(
            of: blue, "blue with the box of the spaced lines", in: picture, lessThan: boxed - 0.001)
        print("text-more: the share of blue with the box \(boxed) and with the box of the spaced lines \(spaced)")
        XCTAssertLessThan(spaced, boxed - 0.001, "blue with the box of the spaced lines")
        screenshot("text-more-03-spaced")

        slider.adjust(toNormalizedSliderPosition: 0.3)
        waitUntil("field 10 below \(wide) after the move back toward the lower end") {
            (spacing(app) ?? Int.max) < wide
        }
        let narrow = spacing(app) ?? Int.max
        print("text-more: field 10 after the move back toward the lower end \(narrow), the slider at \(slider.normalizedSliderPosition)")
        XCTAssertLessThan(narrow, wide)
    }

    /// The picture with everything on is taken before the slider is moved, when the box is in the frame.
    func testAlignmentSpacingAndMarksLeaveTheOtherValuesOfTheText() {
        let app = startMore()
        let picture = element(app, "editor.picture")
        waitForThePicture(app)
        let before = [1, 2, 3, 4, 6, 7, 9].map { field(app, $0) }
        XCTAssertEqual(before, ["1", "naskh", "64", "255,255,255", "960,540", "0", "0+4200"])

        element(app, "text.align.left").tap()
        waitUntil("field 5 left after the tap on that side") { field(app, 5) == "left" }
        element(app, "text.outline").tap()
        waitUntil("field 8 o.. after the tap on the outline") { field(app, 8) == "o.." }
        element(app, "text.shadow").tap()
        waitUntil("field 8 os. after the tap on the shadow") { field(app, 8) == "os." }
        element(app, "text.box").tap()
        waitUntil("field 8 osb after the tap on the box") { field(app, 8) == "osb" }
        let boxed = waitForTheShare(of: blue, "blue with everything on", in: picture, lessThan: blueWithNoBox)
        XCTAssertLessThan(boxed, blueWithNoBox, "blue with everything on")
        screenshot("text-more-04-all-on")

        app.sliders["text.spacing"].adjust(toNormalizedSliderPosition: 0.8)
        waitUntil("field 10 above 0 after the move toward the upper end") { (spacing(app) ?? 0) > 0 }
        print("text-more: field 10 after the move toward the upper end \(field(app, 10))")
        XCTAssertEqual(field(app, 5), "left")
        XCTAssertEqual(field(app, 8), "osb")
        XCTAssertEqual([1, 2, 3, 4, 6, 7, 9].map { field(app, $0) }, before)
    }

    func testTheControlsShowTheValuesOfTheNextTextAndNotOfTheFirst() {
        let app = startMore()
        let left = element(app, "text.align.left")
        let centre = element(app, "text.align.centre")

        left.tap()
        element(app, "text.outline").tap()
        waitUntil("the first text at the left with an outline") {
            field(app, 5) == "left" && field(app, 8) == "o.." && left.isSelected
                && element(app, "text.outline").isSelected
        }
        app.sliders["text.spacing"].adjust(toNormalizedSliderPosition: 0.8)
        waitUntil("field 10 above 0 for the first text") { (spacing(app) ?? 0) > 0 }

        element(app, "text.done").tap()
        waitUntil("the text region gone after the tap on done") { !element(app, "editor.textRegion").exists }
        element(app, "editor.addText").tap()
        let typed = app.textViews["text.field"]
        waitUntil("the field after the tap on the text button") { typed.exists }
        typed.tap()
        // A keyboard that does not come fails nothing here: the typing fails by itself with no focus.
        waitUntil("the keyboard after the tap on the field", expected: 2, required: false) {
            app.keyboards.firstMatch.exists
        }
        typed.typeText("Peace")
        waitUntil("the typed word as the value of the field") { typed.value as? String == "Peace" }

        element(app, "text.tab.more").tap()
        waitUntil("the centre alone selected and no toggle on for the second text") {
            centre.exists && centre.isSelected && !left.isSelected
                && marks.allSatisfy { !element(app, $0).isSelected }
        }
        XCTAssertFalse(element(app, "text.align.right").isSelected)
        XCTAssertEqual(field(app, 1), "2")
        XCTAssertEqual(field(app, 5), "centre")
        XCTAssertEqual(field(app, 8), "...")
        XCTAssertEqual(field(app, 10), "0")
    }

    /// Starts on text-wide at one second, waits for the editor, taps the part button and waits for the
    /// first control of the part.
    private func startMore(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "text-wide", language: language, playhead: 600)
        waitForTheEditor(app)
        waitUntil("the part button text.tab.more after the start") { element(app, "text.tab.more").exists }
        element(app, "text.tab.more").tap()
        waitUntil("the first side button of the part more after the tap on its part button") {
            element(app, "text.align.left").exists
        }
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The field of `editor.textInfo` at the place, counted from 1, or nothing when there is none.
    private func field(_ app: XCUIApplication, _ place: Int) -> String {
        let fields = app.staticTexts["editor.textInfo"].label.split(separator: " ")
        return place <= fields.count ? String(fields[place - 1]) : ""
    }

    /// Field 10 as a number: the line spacing times 100.
    private func spacing(_ app: XCUIApplication) -> Int? {
        Int(field(app, 10))
    }

    /// The picture has come when the share of blue is above B and the white lines of the seed are in it.
    private func waitForThePicture(_ app: XCUIApplication) {
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(
            waitForTheShare(of: blue, "blue", in: picture, moreThan: blueWithNoBox), blueWithNoBox, "blue")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white of the lines", in: picture, moreThan: whiteOfTheLines),
            whiteOfTheLines, "white of the lines")
    }

    /// No element says when a frame is drawn, so the share is asked again until it is more than the one
    /// number or less than the other, whichever is given. Prints the seconds it waited, gives up only
    /// above three times the expected seconds, and answers the last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement,
        moreThan least: Double = -1, lessThan most: Double = 2
    ) -> Double {
        let started = Date()
        var waited: Double = 0
        var found = share(of: colour, in: picture)
        while !(found > least && found < most) && waited <= 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print(
            "text-more: waited \(waited) seconds for a share of \(what) above \(least) and below \(most), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)"
        )
        return found
    }

    /// Reads until the condition holds, for the effect of a tap, of typing or of a move of the slider. It
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
        print("text-more: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
