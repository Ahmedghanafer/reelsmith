#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import XCTest

// The picture of a layer and the instructions of a video composition are internal to the Engine.
@testable import ReelsmithEngine

/// Text in the frames the compositor draws, in the exported file and through the player item, and the refresh
/// of a standing item. The clips and the exported files go into the folder of `ExportTests`. A time is in
/// ticks, 20 a frame. A place is counted from the top left of the canvas. A colour matches within 24 of 255
/// per channel, and within 6 where a test says so. The box is black at 60 percent, so over a colour it reads
/// that colour times 0.4.
final class TextExportTests: XCTestCase {
    /// The export of the plan of text-box-wide, made once for the tests that read it.
    static let textBoxWide = Task<ExportTests.Exported, Error> {
        let plan = try renderPlan(for: Seed.textBoxWide.project)
        return try await ExportTests.exported(plan, clips: Seed.textBoxWide.testClips, name: "text-box-wide.out")
    }

    // MARK: The exported file

    func testTheBoxSeedExportsTo210FramesWithItsBoxFrom600To1500Ticks() async throws {
        let made = try await Self.textBoxWide.value
        XCTAssertEqual(try fileType(of: made.output), "mp42")
        let picture = try await tracks(of: made.file).filter { $0.kind == "vide" }
        XCTAssertEqual(picture.count, 1)
        XCTAssertEqual(picture.first?.duration, CMTime(value: 4200, timescale: 600))
        let size = try await storedSize(of: made.file)
        XCTAssertEqual(size.width, 1920)
        XCTAssertEqual(size.height, 1080)
        let count = try await frameCount(of: made.file)
        XCTAssertEqual(count, 210)

        let layer = try XCTUnwrap(try renderPlan(for: Seed.textBoxWide.project).texts.first)
        let corner = try boxCorner(of: layer)
        let checks: [(Int64, RGB)] = [(580, blue), (600, boxOverBlue), (1480, boxOverBlue), (1500, blue)]
        for (ticks, wanted) in checks {
            let colour = try await frame(of: made.file, at: ticks).colour(corner.x, corner.y)
            XCTAssertLessThanOrEqual(worst(colour, wanted), 24, "the box corner at \(ticks) ticks reads \(colour)")
        }
    }

    func testTheTextOfTheTextSeedIsWhiteForTheWholeVideoOverBlueAndOverRed() async throws {
        let plan = try renderPlan(for: Seed.textWide.project)
        let made = try await ExportTests.exported(plan, clips: Seed.textWide.testClips, name: "text-wide.out")
        let place = try fullPixel(of: XCTUnwrap(plan.texts.first))

        let times: [Int64] = [0, 600, 3000, 4180]
        for ticks in times {
            let colour = try await frame(of: made.file, at: ticks).colour(place.x, place.y)
            XCTAssertLessThanOrEqual(
                worst(colour, white), 24, "(\(place.x), \(place.y)) at \(ticks) ticks reads \(colour)")
        }
    }

    func testThePixelAt100And100ReadsTheSameWithTheBoxedTextAndWithoutIt() async throws {
        let with = try await frame(of: Self.textBoxWide.value.file, at: 900).colour(100, 100)
        let without = try await frame(of: CanvasEngineTests.twoClipsWide.value.file, at: 900).colour(100, 100)
        print("text in the frame: (100, 100) at 900 ticks reads \(with.r), \(with.g), \(with.b) with the text "
            + "and \(without.r), \(without.g), \(without.b) without it")
        XCTAssertLessThanOrEqual(worst(with, without), 6)
    }

    // MARK: The colours

    func testABoxOverTheGreyOfTheMidToneClipReads51InTheExportedFile() async throws {
        let clip = midToneClip()
        let layer = text("BOX", x: 480, y: 540, box: true)
        let plan = handPlan(of: clip, texts: [layer])
        let made = try await ExportTests.exported(plan, clips: [clip], name: "mid-tone-box.out")
        let corner = try boxCorner(of: layer)

        let shot = try await frame(of: made.file, at: 600)
        let box = shot.colour(corner.x, corner.y)
        let beside = shot.colour(100, 100)
        print("text in the frame: a box over 128, 128, 128 reads \(box.r), \(box.g), \(box.b) in the exported "
            + "file, and the grey beside it \(beside.r), \(beside.g), \(beside.b)")
        XCTAssertLessThanOrEqual(worst(box, RGB(r: 51, g: 51, b: 51)), 6, "reads \(box)")
    }

    func testATextIn142And142And147OverBlueHasAPixelOfThatColourInTheExportedFile() async throws {
        let grey = RGB(r: 142, g: 142, b: 147)
        let plan = handPlan(of: .blue, texts: [text("HH", size: 300, colour: grey)])
        let made = try await ExportTests.exported(plan, clips: [.blue], name: "grey-text.out")

        let found = try await frame(of: made.file, at: 600).places { worst($0, grey) <= 6 }
        print("text in the frame: \(found.count) pixels of the exported file are within 6 of 142, 142, 147")
        XCTAssertFalse(found.isEmpty)
    }

    // MARK: The place

    /// With y counted from the bottom the box would stand at 480, 810.
    @MainActor
    func testABoxedTextAt480And270HasItsBoxThereAndTheClipAt1440And810() async throws {
        let layer = text("BOX", x: 480, y: 270, box: true)
        let item = try await playerItem(of: handPlan(of: .blue, texts: [layer]))
        let corner = try boxCorner(of: layer)

        let shot = try await frame(of: item, at: 600)
        let box = shot.colour(corner.x, corner.y)
        let clip = shot.colour(1440, 810)
        XCTAssertLessThanOrEqual(worst(box, boxOverBlue), 24, "(\(corner.x), \(corner.y)) reads \(box)")
        XCTAssertLessThanOrEqual(worst(clip, blue), 24, "(1440, 810) reads \(clip)")
    }

    /// The halves are those of the ink: the stem of the letter stands left and its foot lies below.
    @MainActor
    func testTheLetterLInAFrameHasMoreInkBelowThanAboveAndMoreLeftThanRight() async throws {
        let item = try await playerItem(of: handPlan(of: .blue, texts: [text("L", size: 300)]))
        let ink = try await frame(of: item, at: 600).places { $0.r > 128 }

        let left = try XCTUnwrap(ink.map { $0.x }.min())
        let right = try XCTUnwrap(ink.map { $0.x }.max())
        let top = try XCTUnwrap(ink.map { $0.y }.min())
        let bottom = try XCTUnwrap(ink.map { $0.y }.max())
        let above = ink.filter { $0.y * 2 < top + bottom }.count
        let below = ink.filter { $0.y * 2 > top + bottom }.count
        let leftward = ink.filter { $0.x * 2 < left + right }.count
        let rightward = ink.filter { $0.x * 2 > left + right }.count
        print("text in the frame: the ink of the letter L, \(above) pixels above and \(below) below, "
            + "\(leftward) left and \(rightward) right")
        XCTAssertGreaterThan(below, above)
        XCTAssertGreaterThan(leftward, rightward)
    }

    /// The ink is every pixel that is not the blue of the clip: the box and its letters.
    @MainActor
    func testABoxedWordTurnedBy30HasItsRightEndLowerThanItsLeftEnd() async throws {
        let layer = text("Constantinople", rotation: 30, size: 64, box: true)
        let item = try await playerItem(of: handPlan(of: .blue, texts: [layer]))
        let ink = try await frame(of: item, at: 600).places { worst($0, blue) > 24 }

        XCTAssertFalse(ink.isEmpty)
        let middle = ink.reduce(0) { $0 + $1.x } / max(ink.count, 1)
        let leftEnd = ink.filter { $0.x < middle }
        let rightEnd = ink.filter { $0.x > middle }
        let leftRow = leftEnd.reduce(0) { $0 + $1.y } / max(leftEnd.count, 1)
        let rightRow = rightEnd.reduce(0) { $0 + $1.y } / max(rightEnd.count, 1)
        print("text in the frame: a word turned by 30, mean row \(leftRow) of its left end "
            + "and \(rightRow) of its right end")
        XCTAssertGreaterThan(rightRow, leftRow)
    }

    @MainActor
    func testTheLaterOfTwoTextsAtOnePlaceIsOnTop() async throws {
        let first = text("H", size: 200)
        var second = text("H", size: 200, colour: RGB(r: 255, g: 69, b: 58))
        second.text = TextID(2)
        let item = try await playerItem(of: handPlan(of: .blue, texts: [first, second]))
        let place = try fullPixel(of: first)

        let colour = try await frame(of: item, at: 600).colour(place.x, place.y)
        XCTAssertLessThanOrEqual(worst(colour, RGB(r: 255, g: 69, b: 58)), 24, "reads \(colour)")
    }

    // MARK: The kept pictures

    @MainActor
    func testEachInstructionKeepsThePicturesOfTheTextsThatOverlapIt() async throws {
        let wideItem = try await seedItem(.textWide)
        let boxItem = try await seedItem(.textBoxWide)
        let wide = try instructions(of: wideItem).map { $0.texts.count }
        let box = try instructions(of: boxItem).map { $0.texts.count }
        XCTAssertEqual(wide, [1, 1])
        XCTAssertEqual(box, [1, 0])
    }

    @MainActor
    func testAMoveOrATurnDrawsNoPictureAgainAndAnotherStringStyleOrWrapWidthDrawsOne() async throws {
        let project = Seed.textWide.project
        var plan = try renderPlan(for: project)
        let item = try await seedItem(.textWide)
        let first = try drawnCount(of: item)
        XCTAssertEqual(first, 1)

        var later = 0
        for step in 1...10 {
            plan.texts[0].x += 7
            plan.texts[0].y -= 3
            plan.texts[0].rotation = Double(step * 9)
            try refreshPicture(of: item, plan: plan, media: project.media)
            later += try drawnCount(of: item)
        }
        XCTAssertEqual(later, 0)
        let kept = try instructions(of: item).map { $0.texts.count }
        XCTAssertEqual(kept, [1, 1])

        plan.texts[0].string = "Peace"
        try refreshPicture(of: item, plan: plan, media: project.media)
        let afterString = try drawnCount(of: item)
        XCTAssertEqual(afterString, 1)

        plan.texts[0].style.size = 80
        try refreshPicture(of: item, plan: plan, media: project.media)
        let afterStyle = try drawnCount(of: item)
        XCTAssertEqual(afterStyle, 1)

        plan.texts[0].lineWidth = 400
        try refreshPicture(of: item, plan: plan, media: project.media)
        let afterWidth = try drawnCount(of: item)
        XCTAssertEqual(afterWidth, 1)
    }

    @MainActor
    func testABlankLayerIsLeftOutAndTheFrameIsDrawnWithoutIt() async throws {
        let item = try await playerItem(of: handPlan(of: .blue, texts: [text(" \n ")]))
        let kept = try instructions(of: item).map { $0.texts.count }
        XCTAssertEqual(kept, [0])

        let colour = try await frame(of: item, at: 600).colour(960, 540)
        XCTAssertLessThanOrEqual(worst(colour, blue), 24, "reads \(colour)")
    }

    // MARK: The refresh

    @MainActor
    func testARefreshedItemDrawsTheTextOfTheNewPlan() async throws {
        let item = try await seedItem(.twoClipsWide)
        let project = Seed.textWide.project
        let plan = try renderPlan(for: project)
        let place = try fullPixel(of: XCTUnwrap(plan.texts.first))

        let before = try await frame(of: item, at: 600).places { worst($0, white) <= 24 }
        XCTAssertTrue(before.isEmpty, "\(before.count) white pixels before the refresh")

        try refreshPicture(of: item, plan: plan, media: project.media)
        let after = try await frame(of: item, at: 600).colour(place.x, place.y)
        XCTAssertLessThanOrEqual(worst(after, white), 24, "(\(place.x), \(place.y)) reads \(after)")
    }

    /// The second refusal needs no file of three-clips: a refresh reads none.
    @MainActor
    func testARefreshRefusesAnItemItDidNotMakeAndAPlanWithAnotherNumberOfSegments() async throws {
        let wide = Seed.twoClipsWide.project
        let file = try await writeTestClip(.blue, to: ExportTests.folder)
        let foreign = AVPlayerItem(asset: AVURLAsset(url: file))
        do {
            try refreshPicture(of: foreign, plan: renderPlan(for: wide), media: wide.media)
            XCTFail("an item of another maker was refreshed")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
        XCTAssertNil(foreign.videoComposition)

        let item = try await seedItem(.twoClipsWide)
        let before = try instructions(of: item)
        let three = Seed.threeClips.project
        do {
            try refreshPicture(of: item, plan: renderPlan(for: three), media: three.media)
            XCTFail("a plan of three segments was taken for an item of two")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
        let after = try instructions(of: item)
        XCTAssertEqual(after.count, 2)
        XCTAssertTrue(zip(before, after).allSatisfy { $0 === $1 })
    }

    /// Speed is not judged here. The limit is three times the expected time.
    @MainActor
    func testTheTimeOf60RefreshesIsPrinted() async throws {
        let project = Seed.textWide.project
        var plan = try renderPlan(for: project)
        let item = try await seedItem(.textWide)

        let began = Date()
        for _ in 1...60 {
            plan.texts[0].x += 1
            try refreshPicture(of: item, plan: plan, media: project.media)
        }
        let seconds = Date().timeIntervalSince(began)
        print("text in the frame: 60 refreshes of text-wide, each moved by one pixel, took \(seconds) seconds, "
            + "expected 0.1, limit 0.3")
        XCTAssertLessThanOrEqual(seconds, 0.3)
        let moved = try instructions(of: item).map { $0.texts.count }
        XCTAssertEqual(moved, [1, 1])
    }
}

// MARK: Plans and items

private let blue = RGB(r: 0, g: 0, b: 255)
private let white = RGB(r: 255, g: 255, b: 255)
/// The box over the blue clip.
private let boxOverBlue = RGB(r: 0, g: 0, b: 102)

/// A layer in naskh, centred, for the first two seconds, in the middle of the landscape canvas unless said
/// otherwise.
private func text(
    _ string: String, x: Double = 960, y: Double = 540, rotation: Double = 0, size: Double = 96,
    colour: RGB = RGB(r: 255, g: 255, b: 255), box: Bool = false
) -> TextLayer {
    TextLayer(
        text: TextID(1), string: string, timelineStart: .zero, duration: Time(ticks: 1200), x: x, y: y,
        rotation: rotation,
        style: TextStyle(
            font: .naskh, size: size, colour: colour, align: .centre, lineSpacing: 0, outline: false, shadow: false,
            box: box),
        lineWidth: 1536)
}

/// A plan built by hand: one clip of 1920 by 1080, whole, which fills the landscape canvas, under some texts.
private func handPlan(of clip: TestClip, texts: [TextLayer]) -> RenderPlan {
    let segment = Segment(
        clip: ClipID(1), media: clip.info.id, sourceStart: .zero, timelineStart: .zero, duration: clip.duration,
        placement: Placement(quarterTurns: 0, x: 0, y: 0, width: 1920, height: 1080), hasSound: clip.hasSound)
    return RenderPlan(segments: [segment], duration: clip.duration, canvas: .landscape, texts: texts)
}

/// The player item of a plan built by hand on the blue clip.
@MainActor
private func playerItem(of plan: RenderPlan) async throws -> AVPlayerItem {
    _ = try await writeTestClip(.blue, to: ExportTests.folder)
    return try await makePlayerItem(
        plan: plan, media: [TestClip.blue.info.id: TestClip.blue.info], mediaFolder: ExportTests.folder)
}

/// The player item of the plan of a seed.
@MainActor
private func seedItem(_ seed: Seed) async throws -> AVPlayerItem {
    for clip in seed.testClips {
        _ = try await writeTestClip(clip, to: ExportTests.folder)
    }
    let project = seed.project
    return try await makePlayerItem(
        plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
}

/// The instructions of the video composition an item has.
@MainActor
private func instructions(of item: AVPlayerItem) throws -> [PieceInstruction] {
    try XCTUnwrap(item.videoComposition?.instructions as? [PieceInstruction])
}

/// How many times a text picture was asked for when the video composition the item has was built.
@MainActor
private func drawnCount(of item: AVPlayerItem) throws -> Int {
    try instructions(of: item).reduce(0) { $0 + $1.drawn }
}

// MARK: Places

/// The box corner of an upright layer: 10 pixels inside the top left of its picture, in the padding of the
/// box, where no letter is.
private func boxCorner(of layer: TextLayer) throws -> (x: Int, y: Int) {
    let picture = try XCTUnwrap(textPicture(for: layer))
    return (Int(layer.x - picture.width / 2 + 10), Int(layer.y - picture.height / 2 + 10))
}

/// A place on the canvas where the picture of an upright layer has full alpha, as deep inside a letter as
/// the picture allows, so no edge of a letter is near it.
private func fullPixel(of layer: TextLayer) throws -> (x: Int, y: Int) {
    let picture = try Frame(XCTUnwrap(textPicture(for: layer)).image)
    let left = Int((layer.x - Double(picture.width) / 2).rounded())
    let top = Int((layer.y - Double(picture.height) / 2).rounded())
    for margin in stride(from: 8, through: 1, by: -1) {
        for y in margin..<(picture.height - margin) {
            for x in margin..<(picture.width - margin) where picture.isFull(x, y, margin: margin) {
                print("text in the frame: a pixel of full alpha with \(margin) full pixels on every side "
                    + "stands at (\(left + x), \(top + y))")
                return (left + x, top + y)
            }
        }
    }
    XCTFail("the picture has no pixel of full alpha with a full pixel on every side")
    throw EngineError.cannotRead
}

// MARK: Reading a frame

/// The pixels of a picture as red, green, blue and alpha, the top row first, with the numbers the file or the
/// compositor gave: the colour space of the image is replaced and not converted before it is drawn.
///
/// https://developer.apple.com/documentation/coregraphics/cgimage/copy(colorspace:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
private struct Frame {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) throws {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let plain = try XCTUnwrap(image.copy(colorSpace: space))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: plain.width, height: plain.height, bitsPerComponent: 8, bytesPerRow: plain.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(plain, in: CGRect(x: 0, y: 0, width: plain.width, height: plain.height))
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        width = plain.width
        height = plain.height
        bytes = Array(UnsafeBufferPointer(start: data, count: plain.width * plain.height * 4))
    }

    func colour(_ x: Int, _ y: Int) -> RGB {
        let offset = (y * width + x) * 4
        return RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
    }

    /// Whether the pixel and every pixel up to a margin away from it has full alpha.
    func isFull(_ x: Int, _ y: Int, margin: Int) -> Bool {
        if bytes[(y * width + x) * 4 + 3] != 255 {
            return false
        }
        for row in (y - margin)...(y + margin) {
            for column in (x - margin)...(x + margin) where bytes[(row * width + column) * 4 + 3] != 255 {
                return false
            }
        }
        return true
    }

    /// The places of the pixels whose colour holds a test.
    func places(where holds: (RGB) -> Bool) -> [(x: Int, y: Int)] {
        var found: [(x: Int, y: Int)] = []
        for y in 0..<height {
            for x in 0..<width where holds(colour(x, y)) {
                found.append((x, y))
            }
        }
        return found
    }
}

/// The frame of a file that is shown at a time.
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
private func frame(of file: URL, at ticks: Int64) async throws -> Frame {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try Frame(try await generator.image(at: CMTime(value: ticks, timescale: 600)).image)
}

/// The frame the compositor hands out for a time of a player item, with no encoding between.
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
@MainActor
private func frame(of item: AVPlayerItem, at ticks: Int64) async throws -> Frame {
    let generator = AVAssetImageGenerator(asset: item.asset)
    generator.videoComposition = item.videoComposition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try Frame(try await generator.image(at: CMTime(value: ticks, timescale: 600)).image)
}

/// The largest difference of one channel between two colours.
private func worst(_ colour: RGB, _ wanted: RGB) -> Int {
    max(
        abs(Int(colour.r) - Int(wanted.r)), abs(Int(colour.g) - Int(wanted.g)),
        abs(Int(colour.b) - Int(wanted.b)))
}
#endif
