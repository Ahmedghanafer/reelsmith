import XCTest

// The part look of the text panel, on the seed text-wide with the playhead at one second: three white lines
// over the blue clip on the landscape canvas, text 1 selected and the panel open on its part look. The
// values of the text are read from `editor.textInfo` by the place of a field, counted from 1: position,
// font, size, colour, alignment, centre, rotation, marks, range, line spacing. The picture is read through
// the probe `share(of:in:)`. On the blue clip the letters are the only pixels that are not blue.
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
final class TextLookTests: XCTestCase {
    private let white = (r: 255, g: 255, b: 255)
    private let yellow = (r: 255, g: 214, b: 10)
    private let blue = (r: 0, g: 0, b: 255)

    /// W: with the three white lines in the picture the share of white is more than this, and with the
    /// lines in another colour it is less. A run before this file measured 0.0029 for the white lines.
    private let whiteOfTheLines = 0.0005
    /// Y: with the three lines in yellow the share of 255, 214, 10 is more than this, and before it is less.
    private let yellowOfTheLines = 0.0005

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    private let faces = ["text.font.naskh", "text.font.naskh-bold", "text.font.system"]
    /// The palette in its order, as field 4 writes a colour.
    private let palette = [
        "255,255,255", "0,0,0", "255,214,10", "255,69,58", "48,209,88", "10,132,255", "255,105,180", "142,142,147",
    ]

    func testThePartLookShowsTheFacesTheColoursAndTheSizeOfTheSelectedText() {
        let app = startLook()
        waitForThePicture(app)

        // Three faces in one row from leading to trailing, with their English words.
        let faceButtons = faces.map { element(app, $0) }
        XCTAssertLessThan(faceButtons[0].frame.minX, faceButtons[1].frame.minX)
        XCTAssertLessThan(faceButtons[1].frame.minX, faceButtons[2].frame.minX)
        XCTAssertEqual(faceButtons.map { $0.label }, ["Naskh", "Naskh bold", "System"])
        // Eight colours in one row under the faces, in the order of the palette.
        let colours = (1...8).map { colour(app, $0) }
        for number in 1...8 {
            XCTAssertTrue(colours[number - 1].exists, "text.colour.\(number)")
        }
        for number in 1...7 {
            XCTAssertLessThan(colours[number - 1].frame.minX, colours[number].frame.minX, "text.colour.\(number)")
            XCTAssertEqual(
                Double(colours[number - 1].frame.midY), Double(colours[number].frame.midY), accuracy: 4)
        }
        XCTAssertEqual(colours[0].label, "Colour 1")
        XCTAssertEqual(colours[7].label, "Colour 8")
        XCTAssertGreaterThanOrEqual(colours[0].frame.minY, faceButtons[0].frame.maxY - 1)
        // The slider under the colours.
        let slider = app.sliders["text.size"]
        XCTAssertTrue(slider.exists)
        XCTAssertGreaterThanOrEqual(slider.frame.minY, colours[0].frame.maxY - 1)

        // The controls show the text of the seed: the first face, the first colour, the size 64.
        XCTAssertTrue(faceButtons[0].isSelected)
        XCTAssertFalse(faceButtons[1].isSelected)
        XCTAssertFalse(faceButtons[2].isSelected)
        for number in 1...8 {
            XCTAssertEqual(colours[number - 1].isSelected, number == 1, "text.colour.\(number)")
        }
        XCTAssertEqual(field(app, 3), "64")
        screenshot("text-look-01-look")
    }

    func testATapOnAFaceSetsTheFontAndMovesTheTraitSelected() {
        let app = startLook()
        let naskh = element(app, "text.font.naskh")
        let bold = element(app, "text.font.naskh-bold")
        let system = element(app, "text.font.system")

        bold.tap()
        waitUntil("field 2 naskh-bold and that button alone selected after the tap on it") {
            field(app, 2) == "naskh-bold" && bold.isSelected && !naskh.isSelected && !system.isSelected
        }
        system.tap()
        waitUntil("field 2 system and that button alone selected after the tap on it") {
            field(app, 2) == "system" && system.isSelected && !naskh.isSelected && !bold.isSelected
        }
    }

    /// The first colour is tapped last, so every tap has an effect to wait for.
    func testATapOnEachColourSetsItsColourOfThePalette() {
        let app = startLook()

        for number in [2, 3, 4, 5, 6, 7, 8, 1] {
            colour(app, number).tap()
            waitUntil("field 4 \(palette[number - 1]) and text.colour.\(number) alone selected after the tap on it") {
                field(app, 4) == palette[number - 1]
                    && (1...8).allSatisfy { colour(app, $0).isSelected == ($0 == number) }
            }
        }
    }

    /// With no tap on play and no scrub: the paused picture follows the colour by itself.
    func testThePictureFollowsTheYellowSwatch() {
        let app = startLook()
        let picture = element(app, "editor.picture")
        waitForThePicture(app)
        let whiteBefore = share(of: white, in: picture)
        let yellowBefore = share(of: yellow, in: picture)
        print(
            "text-look: before the tap the share of white is \(whiteBefore), W \(whiteOfTheLines), the share of yellow \(yellowBefore), Y \(yellowOfTheLines)"
        )
        XCTAssertGreaterThan(whiteBefore, whiteOfTheLines, "white before the tap")
        XCTAssertLessThan(yellowBefore, yellowOfTheLines, "yellow before the tap")

        colour(app, 3).tap()
        let yellowAfter = waitForTheShare(
            of: yellow, "yellow after the tap on text.colour.3", in: picture, moreThan: yellowOfTheLines)
        let whiteAfter = share(of: white, in: picture)
        print(
            "text-look: after the tap the share of yellow is \(yellowAfter), Y \(yellowOfTheLines), the share of white \(whiteAfter), W \(whiteOfTheLines)"
        )
        XCTAssertGreaterThan(yellowAfter, yellowOfTheLines, "yellow after the tap")
        XCTAssertLessThan(whiteAfter, whiteOfTheLines, "white after the tap")
        XCTAssertEqual(field(app, 4), "255,214,10")
        screenshot("text-look-02-yellow")
    }

    /// The slider is moved with `adjust(toNormalizedSliderPosition:)`, which does not promise the place it
    /// lands on, so only the direction of each change is asserted. Field 3 is printed around each move.
    func testTheSliderMakesTheTextLargerAndThenSmaller() {
        let app = startLook()
        let slider = app.sliders["text.size"]
        XCTAssertTrue(slider.exists)
        XCTAssertEqual(field(app, 3), "64")
        print("text-look: field 3 before the first move \(field(app, 3)), the slider at \(slider.normalizedSliderPosition)")

        slider.adjust(toNormalizedSliderPosition: 0.8)
        waitUntil("field 3 above 64 after the move toward the upper end") { (size(app) ?? 0) > 64 }
        let large = size(app) ?? 0
        print("text-look: field 3 after the move toward the upper end \(large), the slider at \(slider.normalizedSliderPosition)")
        XCTAssertGreaterThan(large, 64)

        slider.adjust(toNormalizedSliderPosition: 0.3)
        waitUntil("field 3 below \(large) after the move back toward the lower end") {
            (size(app) ?? Int.max) < large
        }
        let small = size(app) ?? Int.max
        print("text-look: field 3 after the move back toward the lower end \(small), the slider at \(slider.normalizedSliderPosition)")
        XCTAssertLessThan(small, large)
    }

    /// The picture of the bold and larger lines is taken when the share of white is more than twice the
    /// share of the lines of the seed. Then a colour is set too, and the last six fields read as before.
    func testFaceSizeAndColourLeaveTheOtherValuesOfTheText() {
        let app = startLook()
        let picture = element(app, "editor.picture")
        waitForThePicture(app)
        let whiteBefore = share(of: white, in: picture)

        element(app, "text.font.naskh-bold").tap()
        waitUntil("field 2 naskh-bold after the tap on that face") { field(app, 2) == "naskh-bold" }
        print("text-look: field 3 before the move toward the upper end \(field(app, 3))")
        app.sliders["text.size"].adjust(toNormalizedSliderPosition: 0.35)
        waitUntil("field 3 above 64 after the move toward the upper end") { (size(app) ?? 0) > 64 }
        print("text-look: field 3 after the move toward the upper end \(field(app, 3))")
        let whiteLarge = waitForTheShare(
            of: white, "white of the bold and larger lines", in: picture, moreThan: 2 * whiteBefore)
        print("text-look: the share of white before \(whiteBefore) and with the bold and larger lines \(whiteLarge)")
        XCTAssertGreaterThan(whiteLarge, 2 * whiteBefore, "white of the bold and larger lines")
        screenshot("text-look-03-bold-large")

        colour(app, 4).tap()
        waitUntil("field 4 255,69,58 after the tap on text.colour.4") { field(app, 4) == "255,69,58" }
        XCTAssertEqual(field(app, 2), "naskh-bold")
        XCTAssertGreaterThan(size(app) ?? 0, 64)
        let info = app.staticTexts["editor.textInfo"].label.split(separator: " ")
        XCTAssertEqual(info.dropFirst(4).joined(separator: " "), "centre 960,540 0 ... 0+4200 0")
    }

    func testTheControlsShowTheValuesOfTheNextTextAndNotOfTheFirst() {
        let app = startLook()
        let naskh = element(app, "text.font.naskh")
        let bold = element(app, "text.font.naskh-bold")

        bold.tap()
        colour(app, 3).tap()
        waitUntil("the first text bold and yellow") {
            field(app, 2) == "naskh-bold" && field(app, 4) == "255,214,10" && bold.isSelected
                && colour(app, 3).isSelected
        }

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

        element(app, "text.tab.look").tap()
        waitUntil("the first face and the first colour alone selected for the second text") {
            naskh.exists && naskh.isSelected && !bold.isSelected && colour(app, 1).isSelected
                && !colour(app, 3).isSelected
        }
        XCTAssertEqual(field(app, 1), "2")
        XCTAssertEqual(field(app, 2), "naskh")
        XCTAssertEqual(field(app, 3), "64")
        XCTAssertEqual(field(app, 4), "255,255,255")
    }

    func testInArabicThePartLookMirrorsAndItsNumbersStayInTheDigitsZeroToNine() {
        let app = startLook(language: "ar")
        waitForThePicture(app)

        // Leading is the right now: the first face and the first colour stand at the right end of their rows.
        XCTAssertGreaterThan(
            element(app, "text.font.naskh").frame.minX, element(app, "text.font.naskh-bold").frame.minX)
        XCTAssertGreaterThan(
            element(app, "text.font.naskh-bold").frame.minX, element(app, "text.font.system").frame.minX)
        XCTAssertGreaterThan(colour(app, 1).frame.minX, colour(app, 8).frame.minX)
        // The number of a swatch in its label, and the size.
        XCTAssertTrue(colour(app, 1).label.contains("1"), colour(app, 1).label)
        XCTAssertTrue(colour(app, 8).label.contains("8"), colour(app, 8).label)
        XCTAssertEqual(field(app, 3), "64")
        XCTAssertTrue(element(app, "text.font.naskh").isSelected)
        XCTAssertTrue(colour(app, 1).isSelected)
        screenshot("text-look-01-look-ar")
    }

    /// Starts on text-wide at one second and waits for the editor, then for the first control of the part.
    private func startLook(language: String = "en") -> XCUIApplication {
        let app = startApp(seed: "text-wide", language: language, playhead: 600)
        waitForTheEditor(app)
        waitUntil("the first face button of the part look after the start") {
            element(app, "text.font.naskh").exists
        }
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The colour button with the number, counted from 1.
    private func colour(_ app: XCUIApplication, _ number: Int) -> XCUIElement {
        element(app, "text.colour.\(number)")
    }

    /// The field of `editor.textInfo` at the place, counted from 1, or nothing when there is none.
    private func field(_ app: XCUIApplication, _ place: Int) -> String {
        let fields = app.staticTexts["editor.textInfo"].label.split(separator: " ")
        return place <= fields.count ? String(fields[place - 1]) : ""
    }

    /// Field 3 as a number.
    private func size(_ app: XCUIApplication) -> Int? {
        Int(field(app, 3))
    }

    /// The picture has come when most of its area is blue and the white lines of the seed are in it.
    private func waitForThePicture(_ app: XCUIApplication) {
        let picture = element(app, "editor.picture")
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        XCTAssertGreaterThan(
            waitForTheShare(of: white, "white of the lines", in: picture, moreThan: whiteOfTheLines),
            whiteOfTheLines, "white of the lines")
    }

    /// No element says when a frame is drawn, so the share is asked again until it is more than wanted.
    /// Prints the seconds it waited, gives up only above three times the expected seconds, and answers
    /// the last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, moreThan wanted: Double
    ) -> Double {
        let started = Date()
        var waited: Double = 0
        var found = share(of: colour, in: picture)
        while !(found > wanted) && waited <= 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print(
            "text-look: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)"
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
        print("text-look: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if required {
            XCTAssertTrue(holds, what)
        }
        return holds
    }
}
