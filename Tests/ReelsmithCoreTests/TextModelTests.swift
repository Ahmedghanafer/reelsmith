import ReelsmithCore
import XCTest

/// The Arabic line of the seed `text-wide`, as its 21 scalars.
let arabicLineScalars: [UInt32] = [
    0x0627, 0x0644, 0x0633, 0x0651, 0x064E, 0x0644, 0x064E, 0x0627, 0x0645, 0x064F, 0x0020,
    0x0639, 0x064E, 0x0644, 0x064E, 0x064A, 0x0652, 0x0643, 0x064F, 0x0645, 0x0652,
]

/// The Arabic line as a string, built from its scalars.
func arabicLine() -> String {
    var line = String.UnicodeScalarView()
    for value in arabicLineScalars {
        if let scalar = Unicode.Scalar(value) {
            line.append(scalar)
        }
    }
    return String(line)
}

/// A text with the standard style in the middle of the landscape canvas.
func textItem(_ id: Int, _ string: String, _ span: TextSpan) -> TextItem {
    TextItem(id: TextID(id), string: string, span: span, x: 960, y: 540, rotation: 0, style: .standard)
}

/// A portrait project of one clip of the given length.
func projectOfOneClip(ticks: Int64) -> Project {
    let info = MediaInfo(
        id: MediaID("long"), fileName: "long.mov", width: 1080, height: 1920, duration: Time(ticks: ticks),
        quarterTurns: 0, hasSound: false)
    var project = Project()
    project.media[info.id] = info
    project.clips = [Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: info.duration)]
    project.nextClipID = 2
    return project
}

final class TextModelTests: XCTestCase {
    func testTheThreeFacesInTheirOrderWithTheirNamesAndTheirWordKeys() {
        XCTAssertEqual(TextFont.allCases, [.naskh, .naskhBold, .system])
        XCTAssertEqual(TextFont.allCases.map(\.rawValue), ["naskh", "naskh-bold", "system"])
        XCTAssertEqual(TextFont.naskh.words, Words("text.font.naskh"))
        XCTAssertEqual(TextFont.naskhBold.words, Words("text.font.naskhBold"))
        XCTAssertEqual(TextFont.system.words, Words("text.font.system"))
        XCTAssertEqual(TextFont.allWords, ["text.font.naskh", "text.font.naskhBold", "text.font.system"])
    }

    func testTheThreeSidesOfAnAlignment() {
        XCTAssertEqual(TextAlign.allCases, [.left, .centre, .right])
        XCTAssertEqual(TextAlign.allCases.map(\.rawValue), ["left", "centre", "right"])
    }

    func testTheStandardStyle() {
        XCTAssertEqual(TextStyle.standard, TextStyle(
            font: .naskh, size: 64, colour: RGB(r: 255, g: 255, b: 255), align: .centre, lineSpacing: 0,
            outline: false, shadow: false, box: false))
    }

    func testThePaletteHoldsItsEightColoursInOrder() {
        XCTAssertEqual(TextStyle.palette, [
            RGB(r: 255, g: 255, b: 255), RGB(r: 0, g: 0, b: 0), RGB(r: 255, g: 214, b: 10),
            RGB(r: 255, g: 69, b: 58), RGB(r: 48, g: 209, b: 88), RGB(r: 10, g: 132, b: 255),
            RGB(r: 255, g: 105, b: 180), RGB(r: 142, g: 142, b: 147),
        ])
    }

    func testATextOfSpacesAndLineBreaksIsBlank() {
        XCTAssertTrue(textItem(1, "", .whole).isBlank)
        XCTAssertTrue(textItem(1, " ", .whole).isBlank)
        XCTAssertTrue(textItem(1, "\n", .whole).isBlank)
        XCTAssertTrue(textItem(1, "  \n  ", .whole).isBlank)
        XCTAssertFalse(textItem(1, "a", .whole).isBlank)
        XCTAssertFalse(textItem(1, arabicLine(), .whole).isBlank)
    }

    func testAStringIsStoredScalarForScalar() {
        let item = textItem(1, "a\n" + arabicLine(), .whole)

        XCTAssertEqual(item.string.unicodeScalars.map(\.value), [0x61, 0x0A] + arabicLineScalars)
    }

    func testANewProjectHasNoTextAndCountsItsTextIdsFrom1() {
        XCTAssertEqual(Project().texts, [])
        XCTAssertEqual(Project().nextTextID, 1)
        XCTAssertEqual(Project(canvas: .landscape).texts, [])
        XCTAssertEqual(Project(canvas: .landscape).nextTextID, 1)
    }

    func testATextAndItsPositionAreFoundByItsId() {
        var project = Project()
        let first = textItem(4, "a", .whole)
        let second = textItem(7, "b", .whole)
        project.texts = [first, second]

        XCTAssertEqual(project.text(TextID(4)), first)
        XCTAssertEqual(project.text(TextID(7)), second)
        XCTAssertNil(project.text(TextID(1)))
        XCTAssertEqual(project.position(of: TextID(4)), 1)
        XCTAssertEqual(project.position(of: TextID(7)), 2)
        XCTAssertNil(project.position(of: TextID(1)))
    }

    func testAWholeTextRunsFromZeroToTheProjectLength() {
        XCTAssertEqual(
            Seed.textWide.project.range(of: TextID(1)), TextRange(start: .zero, duration: Time(ticks: 4200)))
    }

    func testARangeIsCutAtTheProjectEnd() {
        var project = projectOfOneClip(ticks: 1200)
        project.texts = [
            textItem(1, "a", .range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900)))),
            textItem(2, "b", .range(TextRange(start: Time(ticks: 200), duration: Time(ticks: 400)))),
        ]

        XCTAssertEqual(
            project.range(of: TextID(1)), TextRange(start: Time(ticks: 600), duration: Time(ticks: 600)))
        XCTAssertEqual(
            project.range(of: TextID(2)), TextRange(start: Time(ticks: 200), duration: Time(ticks: 400)))
    }

    func testThereIsNoRangeForAnUnknownIdAnEmptyProjectOrAStartAtTheEnd() {
        var empty = Project()
        empty.texts = [
            textItem(1, "a", .whole),
            textItem(2, "b", .range(TextRange(start: .zero, duration: Time(ticks: 600)))),
        ]
        var short = projectOfOneClip(ticks: 1200)
        short.texts = [
            textItem(1, "a", .range(TextRange(start: Time(ticks: 1200), duration: Time(ticks: 600)))),
            textItem(2, "b", .range(TextRange(start: Time(ticks: 1800), duration: Time(ticks: 600)))),
        ]

        XCTAssertNil(short.range(of: TextID(9)))
        XCTAssertNil(empty.range(of: TextID(1)))
        XCTAssertNil(empty.range(of: TextID(2)))
        XCTAssertNil(short.range(of: TextID(1)))
        XCTAssertNil(short.range(of: TextID(2)))
    }

    func testTheFootageIsTheSameWhenOnlyTheTextsDiffer() {
        let plain = Seed.twoClipsWide.project
        var withText = plain
        withText.texts = [textItem(1, "a", .whole)]
        withText.nextTextID = 2

        XCTAssertTrue(plain.sameFootage(as: withText))
        XCTAssertTrue(withText.sameFootage(as: plain))
    }

    func testTheFootageDiffersWithTheCanvasAClipOrAMediaFact() {
        let plain = Seed.twoClipsWide.project
        var otherCanvas = plain
        otherCanvas.canvas = .portrait
        var otherClip = plain
        otherClip.clips[1].duration = Time(ticks: 1200)
        var otherMedia = plain
        otherMedia.media[MediaID("red")]?.hasSound = false

        XCTAssertFalse(plain.sameFootage(as: otherCanvas))
        XCTAssertFalse(plain.sameFootage(as: otherClip))
        XCTAssertFalse(plain.sameFootage(as: otherMedia))
    }
}
