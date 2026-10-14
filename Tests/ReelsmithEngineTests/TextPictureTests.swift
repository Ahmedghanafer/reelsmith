#if canImport(CoreText)
import CoreGraphics
import CoreText
import Foundation
import ReelsmithCore
import XCTest

// The layout of a text, the face of a choice and the picture of a layer are internal to the Engine.
@testable import ReelsmithEngine

/// The faces and the picture of a text, read as numbers: from the layout the face and the direction of every
/// glyph run and the glyph of a letter, from the drawn image its size, the bounds of its ink and its colours.
/// Every text is at size 64. A colour matches within 24 of 255 per channel.
///
/// https://developer.apple.com/documentation/coretext/ctlinegetglyphruns(_:)
/// https://developer.apple.com/documentation/coretext/ctrungetattributes(_:)
/// https://developer.apple.com/documentation/coretext/ctrungetstatus(_:)
/// https://developer.apple.com/documentation/coretext/ctrungetglyphs(_:_:_:)
/// https://developer.apple.com/documentation/coretext/ctrungetstringindices(_:_:_:)
/// https://developer.apple.com/documentation/coretext/ctfontgetcapheight(_:)
/// https://developer.apple.com/documentation/coregraphics/cgfont/postscriptname
final class TextPictureTests: XCTestCase {
    // MARK: The faces

    func testTheBundledFacesCarryTheNamesReadFromTheirFiles() throws {
        let regular = try postScriptName(ofFile: "Amiri-Regular.ttf")
        let bold = try postScriptName(ofFile: "Amiri-Bold.ttf")
        print("PostScript names read from the font files: \(regular) and \(bold)")

        XCTAssertEqual(faceName(of: .naskh), regular)
        XCTAssertEqual(faceName(of: .naskhBold), bold)
        XCTAssertNotEqual(regular, bold)
    }

    func testTheSystemFaceHasANameOfItsOwnAndAFaceAskedForTwiceIsTheSame() {
        let system = faceName(of: .system)

        XCTAssertFalse(system.isEmpty)
        XCTAssertNotEqual(system, faceName(of: .naskh))
        XCTAssertNotEqual(system, faceName(of: .naskhBold))
        for choice in TextFont.allCases {
            XCTAssertEqual(faceName(of: choice), faceName(of: choice), choice.rawValue)
        }
    }

    /// No bound is asserted: the number is read from the log and judged against the letters of her Reel.
    func testPrintsTheCapHeightOfNaskhAtSize64() {
        print("Cap height of naskh at size 64: \(CTFontGetCapHeight(font(.naskh, size: 64))) canvas pixels")
    }

    // MARK: From the layout

    func testEveryRunOfTheArabicLineIsOfItsFaceAndRunsRightToLeft() {
        for choice in [TextFont.naskh, .naskhBold] {
            for line in [marked, bare] {
                let found = runs(of: layer(line, font: choice))

                XCTAssertFalse(found.isEmpty, choice.rawValue)
                for run in found {
                    XCTAssertEqual(face(of: run), faceName(of: choice), choice.rawValue)
                    XCTAssertTrue(CTRunGetStatus(run).contains(.rightToLeft), choice.rawValue)
                }
            }
        }
    }

    /// A run of Arabic letters runs right to left in any paragraph, so the direction of the paragraph is read
    /// from a full stop after an Arabic word: it stands left of every letter only when the line itself runs
    /// right to left.
    func testTheDirectionOfALineIsLeftToItsOwnText() throws {
        let word = "\u{0639}\u{0644}\u{064A}\u{0643}\u{0645}"
        var stop: CGFloat?
        var letters: [CGFloat] = []
        for run in runs(of: layer(word + ".")) {
            let count = CTRunGetGlyphCount(run)
            var places = [CFIndex](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &places)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for index in 0..<count {
                if places[index] == word.utf16.count {
                    stop = positions[index].x
                } else {
                    letters.append(positions[index].x)
                }
            }
        }

        XCTAssertLessThan(try XCTUnwrap(stop), try XCTUnwrap(letters.min()))
    }

    /// The last lam, the ain and the last meem of the line each stand joined inside a word.
    func testAJoinedLetterHasAnotherGlyphThanTheLetterAlone() throws {
        for choice in TextFont.allCases {
            for line in [marked, bare] {
                for letter in [UInt16(0x0644), 0x0639, 0x0645] {
                    let place = try XCTUnwrap(Array(line.utf16).lastIndex(of: letter))
                    let joined = try XCTUnwrap(glyph(at: place, in: layer(line, font: choice)))
                    let alone = try XCTUnwrap(
                        glyph(at: 0, in: layer(String(utf16CodeUnits: [letter], count: 1), font: choice)))

                    XCTAssertNotEqual(joined, alone, "\(choice.rawValue), the letter \(letter)")
                }
            }
        }
    }

    func testEveryRunOfALatinLineInNaskhIsOfNaskhAndRunsLeftToRight() {
        let found = runs(of: layer("Peace"))

        XCTAssertFalse(found.isEmpty)
        for run in found {
            XCTAssertEqual(face(of: run), faceName(of: .naskh))
            XCTAssertFalse(CTRunGetStatus(run).contains(.rightToLeft))
        }
    }

    func testTheSystemFaceDrawsTheMarkedLineWithNoBundledFace() {
        let system = layer(marked, font: .system)

        XCTAssertNotNil(textPicture(for: system))
        let found = runs(of: system)
        XCTAssertFalse(found.isEmpty)
        for run in found {
            XCTAssertNotEqual(face(of: run), faceName(of: .naskh))
            XCTAssertNotEqual(face(of: run), faceName(of: .naskhBold))
            XCTAssertTrue(CTRunGetStatus(run).contains(.rightToLeft))
        }
    }

    // MARK: From the drawn image, the Arabic line

    func testTheImageOfJoinedLettersIsNarrowerThanTheLettersHeldApart() throws {
        let apart = bare.unicodeScalars.map { String($0) }.joined(separator: "\u{200C}")
        for choice in TextFont.allCases {
            let joined = try inkWidth(of: layer(bare, font: choice))
            let held = try inkWidth(of: layer(apart, font: choice))

            XCTAssertLessThan(joined, held, choice.rawValue)
        }
    }

    func testTheMarksStandOnTheirLetters() throws {
        for choice in TextFont.allCases {
            let with = try Pixels(XCTUnwrap(textPicture(for: layer(marked, font: choice))).image)
            let without = try Pixels(XCTUnwrap(textPicture(for: layer(bare, font: choice))).image)

            XCTAssertEqual(with.height, without.height, choice.rawValue)
            let rows = 0..<min(with.height, without.height)
            XCTAssertTrue(
                rows.contains { with.ink(rows: $0..<$0 + 1) != nil && without.ink(rows: $0..<$0 + 1) == nil },
                choice.rawValue)
            // The marks stand above their letters, so the ink of the marked line begins in a higher row.
            let inkWith = try XCTUnwrap(with.ink(rows: 0..<with.height))
            let inkWithout = try XCTUnwrap(without.ink(rows: 0..<without.height))
            XCTAssertLessThan(inkWith.top, inkWithout.top, choice.rawValue)
            let difference = with.width - without.width
            let inkDifference = inkWith.right - inkWith.left - (inkWithout.right - inkWithout.left)
            print("Width of the marked line less the bare line in \(choice.rawValue) at size 64: \(difference) pixels")
            print("Width of the ink of the marked line less the bare line in \(choice.rawValue): \(inkDifference) pixels")
            // The first run on the hosted Mac printed 17 for both faces of Amiri, with the letters joined, and 0
            // for the system face. The marks of Amiri have no advance of their own in its files, so the width
            // comes from how the face sets the letters under them. The bound is the printed number and 1.
            XCTAssertLessThanOrEqual(abs(difference), 18, choice.rawValue)
        }
    }

    func testTheThreeLinesOfTheSeedAreTallerThanTheFirstLineAlone() throws {
        let seed = try seedLayer()
        let three = try XCTUnwrap(textPicture(for: seed))
        let one = try XCTUnwrap(textPicture(for: layer("Peace")))

        XCTAssertEqual(seed.string, "Peace\n" + marked + "\nbe upon you")
        XCTAssertGreaterThan(three.image.height, one.image.height)
    }

    // MARK: The rectangle

    func testThePictureOfTheSeedIsTheRectangleOfItsBlockWithTheInkInside() throws {
        let picture = try XCTUnwrap(textPicture(for: try seedLayer()))
        let pixels = try Pixels(picture.image)
        let ink = try XCTUnwrap(pixels.ink(rows: 0..<pixels.height))
        let block = textBlock(for: try seedLayer())

        // The block grown by 0.3 of the size on every side, which is 38.4 at size 64.
        print("The picture of the seed is \(picture.width) by \(picture.height), its block \(block.width) by \(block.height)")
        XCTAssertEqual(picture.width, block.width + 38.4, accuracy: 0.01)
        XCTAssertEqual(picture.height, block.height + 38.4, accuracy: 0.01)
        XCTAssertEqual(picture.image.width, Int(picture.width.rounded(.up)))
        XCTAssertEqual(picture.image.height, Int(picture.height.rounded(.up)))
        XCTAssertLessThanOrEqual(picture.image.width, 1575)
        // Every pixel of the outermost rows and columns is clear.
        XCTAssertGreaterThan(ink.left, 0)
        XCTAssertGreaterThan(ink.top, 0)
        XCTAssertLessThan(ink.right, pixels.width - 1)
        XCTAssertLessThan(ink.bottom, pixels.height - 1)
    }

    func testTheBoxFillsTheImageToItsFourCornersAndChangesNoSize() throws {
        let boxed = try Pixels(XCTUnwrap(textPicture(for: layer("BOX", box: true))).image)
        let plain = try Pixels(XCTUnwrap(textPicture(for: layer("BOX"))).image)

        XCTAssertEqual(boxed.width, plain.width)
        XCTAssertEqual(boxed.height, plain.height)
        for (x, y) in [(0, 0), (boxed.width - 1, 0), (0, boxed.height - 1), (boxed.width - 1, boxed.height - 1)] {
            XCTAssertLessThanOrEqual(abs(boxed.alpha(x, y) - 153), 24, "the corner \(x), \(y)")
            XCTAssertLessThanOrEqual(worst(boxed.colour(x, y), RGB(r: 0, g: 0, b: 0)), 24, "the corner \(x), \(y)")
            XCTAssertEqual(plain.alpha(x, y), 0, "the corner \(x), \(y)")
        }
    }

    func testALongLineWrapsAtTheLineWidthOfItsLayer() throws {
        let forty = Array(repeating: "word", count: 40).joined(separator: " ")
        let word = try XCTUnwrap(textPicture(for: layer("word")))
        let wide = try XCTUnwrap(textPicture(for: layer(forty)))
        let narrow = try XCTUnwrap(textPicture(for: layer(forty, lineWidth: 400)))

        XCTAssertLessThanOrEqual(wide.image.width, 1575)
        XCTAssertGreaterThan(wide.image.height, word.image.height)
        XCTAssertLessThanOrEqual(narrow.image.width, 439)
        XCTAssertGreaterThan(narrow.image.height, wide.image.height)
    }

    /// A short line above a long one that begins and ends with the same letters, so the ink of both stands
    /// equally far from the side they share. The long line fills the block from padding to padding.
    func testTheAlignmentIsASideOfThePictureInLatinAndInArabic() throws {
        let arabicShort = "\u{0627}\u{0644}\u{0643}\u{0645}"
        for (short, long) in [("aba", "aba aba aba aba aba"), (arabicShort, bare)] {
            for align in TextAlign.allCases {
                let pixels = try Pixels(
                    XCTUnwrap(textPicture(for: layer(short + "\n" + long, align: align))).image)
                let above = try XCTUnwrap(pixels.ink(rows: 0..<pixels.height / 2))
                let below = try XCTUnwrap(pixels.ink(rows: pixels.height / 2..<pixels.height))
                let what = "\(align.rawValue), \(short == "aba" ? "Latin" : "Arabic"): above \(above), below \(below)"

                switch align {
                case .left:
                    XCTAssertLessThanOrEqual(abs(above.left - below.left), 1, what)
                    XCTAssertLessThanOrEqual(above.left, 27, what)
                    XCTAssertLessThan(above.right, pixels.width / 2, what)
                case .right:
                    XCTAssertLessThanOrEqual(abs(above.right - below.right), 1, what)
                    XCTAssertGreaterThanOrEqual(above.right, pixels.width - 28, what)
                    XCTAssertGreaterThan(above.left, pixels.width / 2, what)
                case .centre:
                    // Two pixels on the middle are four on the sum of both ends.
                    XCTAssertLessThanOrEqual(abs(above.left + above.right - below.left - below.right), 4, what)
                }
            }
        }
    }

    /// A wrapped line ends with the space it was broken at, which stands on the left of an Arabic line. Six
    /// times one word gives lines of the same words, so each is as wide as the block and its ink reaches both
    /// paddings. The upper half of the image holds only lines that were wrapped.
    func testAWrappedArabicLineStandsBetweenThePaddingsWithEveryAlignment() throws {
        let words = Array(repeating: "\u{0639}\u{0644}\u{064A}\u{0643}\u{0645}", count: 6).joined(separator: " ")
        for align in TextAlign.allCases {
            let pixels = try Pixels(XCTUnwrap(textPicture(for: layer(words, align: align, lineWidth: 400))).image)
            let ink = try XCTUnwrap(pixels.ink(rows: 0..<pixels.height / 2))
            let what = "\(align.rawValue): \(ink) in a width of \(pixels.width)"

            XCTAssertLessThanOrEqual(pixels.width, 439, what)
            XCTAssertGreaterThan(ink.left, 0, what)
            XCTAssertLessThanOrEqual(ink.left, 27, what)
            XCTAssertLessThan(ink.right, pixels.width - 1, what)
            XCTAssertGreaterThanOrEqual(ink.right, pixels.width - 28, what)
        }
    }

    func testLineSpacingOfOneAddsTheSizeBetweenTwoLines() throws {
        let tight = try XCTUnwrap(textPicture(for: layer("ab\ncd")))
        let loose = try XCTUnwrap(textPicture(for: layer("ab\ncd", lineSpacing: 1)))

        XCTAssertLessThanOrEqual(abs(loose.image.height - tight.image.height - 64), 1)
    }

    // MARK: The colour and the three switches

    func testEveryFullPixelHasTheColourOfTheText() throws {
        for wanted in [RGB(r: 255, g: 214, b: 10), RGB(r: 255, g: 255, b: 255)] {
            let pixels = try Pixels(XCTUnwrap(textPicture(for: layer("Peace\n" + marked, colour: wanted))).image)
            var full = 0
            var furthest = 0
            for y in 0..<pixels.height {
                for x in 0..<pixels.width where pixels.alpha(x, y) == 255 {
                    full += 1
                    furthest = max(furthest, worst(pixels.colour(x, y), wanted))
                }
            }

            XCTAssertGreaterThan(full, 0, "\(wanted)")
            XCTAssertLessThanOrEqual(furthest, 24, "\(wanted)")
        }
    }

    func testTheOutlineIsBlackAroundWhiteLettersAndWhiteAroundBlackOnes() throws {
        let white = RGB(r: 255, g: 255, b: 255)
        let black = RGB(r: 0, g: 0, b: 0)
        for (colour, line) in [(white, black), (black, white)] {
            let plain = try Pixels(XCTUnwrap(textPicture(for: layer("Peace", colour: colour))).image)
            let outlined = try Pixels(
                XCTUnwrap(textPicture(for: layer("Peace", colour: colour, outline: true))).image)
            XCTAssertEqual(outlined.width, plain.width)
            XCTAssertEqual(outlined.height, plain.height)
            var lineWhereNothingWas = 0
            var fill = 0
            for y in 0..<min(plain.height, outlined.height) {
                for x in 0..<min(plain.width, outlined.width) where outlined.alpha(x, y) == 255 {
                    if plain.alpha(x, y) == 0 && worst(outlined.colour(x, y), line) <= 24 {
                        lineWhereNothingWas += 1
                    }
                    if worst(outlined.colour(x, y), colour) <= 24 {
                        fill += 1
                    }
                }
            }

            XCTAssertGreaterThan(lineWhereNothingWas, 0, "letters in \(colour)")
            XCTAssertGreaterThan(fill, 0, "letters in \(colour)")
            // On each side the ink grows by no more than 0.08 of the size and 1 pixel.
            let before = try XCTUnwrap(plain.ink(rows: 0..<plain.height))
            let after = try XCTUnwrap(outlined.ink(rows: 0..<outlined.height))
            let most = 0.08 * 64 + 1
            XCTAssertLessThanOrEqual(Double(before.left - after.left), most, "letters in \(colour)")
            XCTAssertLessThanOrEqual(Double(after.right - before.right), most, "letters in \(colour)")
            XCTAssertLessThanOrEqual(Double(before.top - after.top), most, "letters in \(colour)")
            XCTAssertLessThanOrEqual(Double(after.bottom - before.bottom), most, "letters in \(colour)")
            // The line shows 0.08 of the size around the letters, which is 5.12 pixels.
            print("With the outline the ink of letters in \(colour) grows to the left by \(before.left - after.left) pixels")
            XCTAssertGreaterThanOrEqual(before.left - after.left, 4, "letters in \(colour)")
        }
    }

    func testTheShadowIsBlackAtNoMoreThanSixtyPercentAndFallsDown() throws {
        let plain = try Pixels(XCTUnwrap(textPicture(for: layer("Peace"))).image)
        let shaded = try Pixels(XCTUnwrap(textPicture(for: layer("Peace", shadow: true))).image)
        XCTAssertEqual(shaded.width, plain.width)
        XCTAssertEqual(shaded.height, plain.height)
        var shadow = 0
        var strongest = 0
        var furthest = 0
        for y in 0..<min(plain.height, shaded.height) {
            for x in 0..<min(plain.width, shaded.width) where plain.alpha(x, y) == 0 && shaded.alpha(x, y) > 0 {
                shadow += 1
                strongest = max(strongest, shaded.alpha(x, y))
                furthest = max(furthest, worst(shaded.colour(x, y), RGB(r: 0, g: 0, b: 0)))
            }
        }

        XCTAssertGreaterThan(shadow, 0)
        XCTAssertLessThanOrEqual(strongest, 153 + 24)
        XCTAssertLessThanOrEqual(furthest, 24)
        let before = try XCTUnwrap(plain.ink(rows: 0..<plain.height))
        let after = try XCTUnwrap(shaded.ink(rows: 0..<shaded.height))
        XCTAssertGreaterThan(after.bottom - before.bottom, before.top - after.top)
        // Moved down by 0.06 of the size, the shadow reaches twice that further below, which is 7.68 pixels.
        let further = (after.bottom - before.bottom) - (before.top - after.top)
        print("The shadow reaches \(after.bottom - before.bottom) pixels below and \(before.top - after.top) above: \(further) further below")
        XCTAssertGreaterThanOrEqual(further, 6)
    }

    // MARK: What a picture depends on

    func testABlankStringGivesNoPicture() {
        for string in ["", "   ", "\n", " \n \n"] {
            XCTAssertNil(textPicture(for: layer(string)), "\"\(string)\"")
        }
    }

    func testTwoLayersThatDifferInIdTimePlaceAndTurnGiveTheSamePicture() throws {
        let first = layer("Peace\n" + marked)
        var second = first
        second.text = TextID(2)
        second.timelineStart = Time(ticks: 300)
        second.duration = Time(ticks: 900)
        second.x = 100
        second.y = 200
        second.rotation = 45
        let one = try Pixels(XCTUnwrap(textPicture(for: first)).image)
        let other = try Pixels(XCTUnwrap(textPicture(for: second)).image)

        XCTAssertEqual(one.width, other.width)
        XCTAssertEqual(one.height, other.height)
        XCTAssertTrue(one.bytes == other.bytes)
    }
}

// MARK: The lines of the seed

/// The Arabic line of the seed `text-wide`, with its nine marks: 21 scalars.
private let marked = String(Seed.textWide.project.texts[0].string.split(separator: "\n")[1])

/// The same line without its marks: 12 scalars.
private let bare = String(
    String.UnicodeScalarView(
        marked.unicodeScalars.filter { ![0x0651, 0x064E, 0x064F, 0x0652].contains($0.value) }))

/// The layer of the text of `text-wide`, as the plan gives it.
private func seedLayer() throws -> TextLayer {
    try XCTUnwrap(try renderPlan(for: Seed.textWide.project).texts.first)
}

/// A layer at size 64, white, centred and wrapped at 1536 unless said otherwise.
private func layer(
    _ string: String, font: TextFont = .naskh, colour: RGB = RGB(r: 255, g: 255, b: 255),
    align: TextAlign = .centre, lineSpacing: Double = 0, outline: Bool = false, shadow: Bool = false,
    box: Bool = false, lineWidth: Double = 1536
) -> TextLayer {
    TextLayer(
        text: TextID(1), string: string, timelineStart: .zero, duration: Time(ticks: 600), x: 960, y: 540,
        rotation: 0,
        style: TextStyle(
            font: font, size: 64, colour: colour, align: align, lineSpacing: lineSpacing, outline: outline,
            shadow: shadow, box: box),
        lineWidth: lineWidth)
}

// MARK: Reading the layout

private func runs(of layer: TextLayer) -> [CTRun] {
    textBlock(for: layer).lines.flatMap { CTLineGetGlyphRuns($0.line) as! [CTRun] }
}

/// The PostScript name of the face a run was laid out in.
private func face(of run: CTRun) -> String {
    let font = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
    return CTFontCopyPostScriptName(font) as String
}

/// The glyph that draws the UTF-16 unit at a place of a string of one line: the glyph whose own place in the
/// string is the nearest at or before it.
private func glyph(at place: Int, in layer: TextLayer) -> CGGlyph? {
    var best: (place: Int, glyph: CGGlyph)?
    for run in runs(of: layer) {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var places = [CFIndex](repeating: 0, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &places)
        for index in 0..<count where places[index] <= place && places[index] >= (best?.place ?? -1) {
            best = (places[index], glyphs[index])
        }
    }
    return best?.glyph
}

/// The PostScript name a font file of the repository gives, read from the file with no face registered.
private func postScriptName(ofFile name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ReelsmithEngine/Fonts")
        .appendingPathComponent(name)
    let provider = try XCTUnwrap(CGDataProvider(url: url as CFURL))
    let font = try XCTUnwrap(CGFont(provider))
    return try XCTUnwrap(font.postScriptName) as String
}

// MARK: Reading the image

/// The first and last column and row that hold a pixel with any alpha.
private struct Ink: Equatable {
    var left: Int
    var right: Int
    var top: Int
    var bottom: Int
}

/// The pixels of an image as red, green, blue and alpha, the top row first.
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
private struct Pixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        width = image.width
        height = image.height
        bytes = Array(UnsafeBufferPointer(start: data, count: image.width * image.height * 4))
    }

    func alpha(_ x: Int, _ y: Int) -> Int {
        Int(bytes[(y * width + x) * 4 + 3])
    }

    /// The stored colour, which is the colour of the pixel where its alpha is full and black where it is black.
    func colour(_ x: Int, _ y: Int) -> RGB {
        let offset = (y * width + x) * 4
        return RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
    }

    /// The bounds of the ink in some rows, nil when they hold none.
    func ink(rows: Range<Int>) -> Ink? {
        var found: Ink?
        for y in rows {
            for x in 0..<width where alpha(x, y) > 0 {
                found = Ink(
                    left: min(found?.left ?? x, x), right: max(found?.right ?? x, x), top: found?.top ?? y,
                    bottom: y)
            }
        }
        return found
    }
}

/// The width of the drawn ink of a layer, from its first column to its last.
private func inkWidth(of layer: TextLayer) throws -> Int {
    let pixels = try Pixels(XCTUnwrap(textPicture(for: layer)).image)
    let ink = try XCTUnwrap(pixels.ink(rows: 0..<pixels.height))
    return ink.right - ink.left
}

/// The largest difference of one channel between two colours.
private func worst(_ colour: RGB, _ wanted: RGB) -> Int {
    max(
        abs(Int(colour.r) - Int(wanted.r)), abs(Int(colour.g) - Int(wanted.g)),
        abs(Int(colour.b) - Int(wanted.b)))
}
#endif
