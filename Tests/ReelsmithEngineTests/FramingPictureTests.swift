#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ReelsmithCore
@testable import ReelsmithEngine
import XCTest

/// Fill, zoom, offset and the blurred backdrop drawn by the compositor from the plan, in the export, the cover and
/// the item. Every plan is on the portrait canvas at 1080p and 30, made by `renderPlan(for:)`, and every export goes
/// through `exported` of `ExportTests`, in its folder. A frame is read at 1 second. A share is the part of the
/// pixels of the 10 by 10 square around a point, within 24 per channel of a colour (rule 8).
final class FramingPictureTests: XCTestCase {
    /// A clip of 1920 by 1080, red on its left half and blue on its right, no sound, 1800 ticks.
    static let halves = TestClip(
        name: "halves", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 1800), framesPerSecond: 30,
        quarterTurns: 0, hasSound: false, left: RGB(r: 255, g: 0, b: 0), right: RGB(r: 0, g: 0, b: 255))

    /// The exports of two-clips with blue at four framings, each made once for the tests that read it.
    static let standard = Task<ExportTests.Exported, Error> {
        try await twoClips(blue: .standard, name: "framing-standard.out")
    }
    static let fill = Task<ExportTests.Exported, Error> {
        try await twoClips(blue: Framing(fit: .fill), name: "framing-fill.out")
    }
    static let zoomed = Task<ExportTests.Exported, Error> {
        try await twoClips(blue: Framing(zoom: 1.5), name: "framing-zoomed.out")
    }
    static let movedUp = Task<ExportTests.Exported, Error> {
        try await twoClips(blue: Framing(zoom: 2, y: -0.18), name: "framing-moved-up.out")
    }

    /// The exports of halves twice, 6 seconds, with a blurred and a black backdrop, each made once.
    static let halvesBlurred = Task<ExportTests.Exported, Error> {
        try await ExportTests.exported(
            halvesPlan(.blurred), clips: [halves], name: "framing-halves-blurred.out")
    }
    static let halvesBlack = Task<ExportTests.Exported, Error> {
        try await ExportTests.exported(halvesPlan(.black), clips: [halves], name: "framing-halves-black.out")
    }

    // 1. Fill covers the bars.
    func testBlueAtFillReadsBlueAtTheTopAndTheBottomWhereTheStandardFramingReadsBlack() async throws {
        let filled = try await frame(of: Self.fill.value.file)
        let standing = try await frame(of: Self.standard.value.file)
        for (x, y) in [(540, 100), (540, 1820)] {
            XCTAssertGreaterThan(try share(of: blue, in: filled, x: x, y: y), 0.9, "fill at (\(x), \(y))")
            XCTAssertGreaterThan(try share(of: black, in: standing, x: x, y: y), 0.9, "standard at (\(x), \(y))")
        }
    }

    // 2. A zoom of 1.5 is 911.25 high from y 504.4, a zoom of 2 moved up stands from y 6.9.
    func testBlueZoomedReadsBlackAboveAndBlueInsideAndMovedUpReadsBlueAtTheTop() async throws {
        let zoomed = try await frame(of: Self.zoomed.value.file)
        XCTAssertGreaterThan(try share(of: black, in: zoomed, x: 540, y: 450), 0.9, "zoom 1.5 at (540, 450)")
        XCTAssertGreaterThan(try share(of: blue, in: zoomed, x: 540, y: 560), 0.9, "zoom 1.5 at (540, 560)")
        let movedUp = try await frame(of: Self.movedUp.value.file)
        XCTAssertGreaterThan(try share(of: blue, in: movedUp, x: 540, y: 20), 0.9, "zoom 2, y -0.18 at (540, 20)")
    }

    // 3. The blurred backdrop is red over the left of the source and blue over its right, the picture unchanged.
    func testHalvesBlurredReadRedAndBlueInTheTopBarAndTheMiddleAsAtBlack() async throws {
        let blurred = try await frame(of: Self.halvesBlurred.value.file)
        let plain = try await frame(of: Self.halvesBlack.value.file)

        let left = try mean(in: blurred, x: 108, y: 300)
        let right = try mean(in: blurred, x: 972, y: 300)
        print("framing picture: halves blurred at (108, 300) \(left), at (972, 300) \(right)")
        XCTAssertGreaterThan(left.r, 127.5, "red at (108, 300)")
        XCTAssertGreaterThan(left.r, max(left.g, left.b), "red the largest at (108, 300)")
        XCTAssertGreaterThan(right.b, 127.5, "blue at (972, 300)")
        XCTAssertGreaterThan(right.b, max(right.r, right.g), "blue the largest at (972, 300)")

        // A bug a review found: the first row of the canvas, where the fill meets its edge, was darkened.
        let edge = try mean(in: blurred, CGRect(x: 103, y: 0, width: 10, height: 1))
        print("framing picture: halves blurred, the first row at x 108 \(edge)")
        XCTAssertGreaterThan(edge.r, 127.5, "red in the first row at x 108")

        let middle = try mean(in: blurred, x: 540, y: 960)
        let middleAtBlack = try mean(in: plain, x: 540, y: 960)
        print("framing picture: the middle blurred \(middle), black \(middleAtBlack)")
        XCTAssertEqual(middle.r, middleAtBlack.r, accuracy: 24, "the middle, red")
        XCTAssertEqual(middle.g, middleAtBlack.g, accuracy: 24, "the middle, green")
        XCTAssertEqual(middle.b, middleAtBlack.b, accuracy: 24, "the middle, blue")

        for (x, y) in [(108, 300), (972, 300)] {
            XCTAssertGreaterThan(try share(of: black, in: plain, x: x, y: y), 0.9, "black at (\(x), \(y))")
        }
    }

    // 4. The cover is drawn by the compositor, the backdrop with it.
    func testTheCoverOfHalvesBlurredHasATopBarThatIsNotBlack() async throws {
        let folder = ExportTests.folder
        _ = try await writeTestClip(Self.halves, to: folder)
        let file = folder.appendingPathComponent("framing-halves-blurred.cover.jpg")
        let plan = try Self.halvesPlan(.blurred)
        try await writeCover(plan: plan, media: [Self.halves.info.id: Self.halves.info], mediaFolder: folder, to: file)

        let ciImage = try XCTUnwrap(CIImage(contentsOf: file), "Core Image cannot read the cover")
        let cover = try XCTUnwrap(CIContext().createCGImage(ciImage, from: ciImage.extent))
        let top = CGRect(x: 0, y: 0, width: cover.width, height: cover.height / 10)
        let colour = try mean(in: cover, top)
        let level = (colour.r + colour.g + colour.b) / 3 / 255
        print("framing picture: the top tenth of the cover \(colour), a mean of \(level) of full")
        XCTAssertGreaterThan(level, 0.2)
    }

    // 5. A change of framing is a refresh of the standing item.
    @MainActor
    func testRefreshPictureOfTwoClipsWithBlueAtFillSucceedsAndBlueHoldsTheNewTransform() async throws {
        for clip in Seed.twoClips.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        var project = Seed.twoClips.project
        let item = try await makePlayerItem(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
        let source = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let before = try XCTUnwrap(item.videoComposition?.instructions.first as? PieceInstruction)

        XCTAssertEqual(project.clips[0].media, TestClip.blue.info.id)
        project.clips[0].framing = Framing(fit: .fill)
        let plan = try renderPlan(for: project)
        try refreshPicture(of: item, plan: plan, media: project.media)

        let pieces = try XCTUnwrap(item.videoComposition?.instructions as? [PieceInstruction])
        XCTAssertEqual(pieces.count, 2)
        let place = plan.segments[0].placement
        // The place counted from the bottom left, as the compositor counts.
        let wanted = (
            minX: place.x, minY: Double(plan.height) - place.y - place.height, width: place.width,
            height: place.height)
        let placed = source.applying(pieces[0].placing)
        print("framing picture: blue before \(source.applying(before.placing)), after \(placed), wanted \(wanted)")
        XCTAssertEqual(Double(placed.minX), wanted.minX, accuracy: 0.01)
        XCTAssertEqual(Double(placed.minY), wanted.minY, accuracy: 0.01)
        XCTAssertEqual(Double(placed.width), wanted.width, accuracy: 0.01)
        XCTAssertEqual(Double(placed.height), wanted.height, accuracy: 0.01)
        XCTAssertGreaterThan(Double(placed.height), 1919.99, "blue fills the height")
        XCTAssertLessThan(Double(source.applying(before.placing).height), 1000, "blue fitted before")
    }

    // 6. The time of the blur, printed. Rule 17: expected at twice black, fails at six times black.
    func testTheSecondsOfAnExportOfHalvesBlurredAndBlackArePrinted() async throws {
        let plain = try await Self.halvesBlack.value.seconds
        let blurred = try await Self.halvesBlurred.value.seconds
        print("framing picture: an export of halves for 6 seconds at 1080p and 30 took \(blurred) seconds blurred "
            + "and \(plain) seconds black, \(blurred / plain) times, expected 2, failing at 6")
        XCTAssertLessThan(blurred, plain * 6)
    }

    /// Two-clips with blue at the framing, exported.
    static func twoClips(blue framing: Framing, name: String) async throws -> ExportTests.Exported {
        var project = Seed.twoClips.project
        project.clips[0].framing = framing
        return try await ExportTests.exported(
            renderPlan(for: project), clips: Seed.twoClips.testClips, name: name)
    }

    /// A portrait plan of halves twice from its start, 3600 ticks, fitted with the backdrop.
    static func halvesPlan(_ backdrop: Backdrop) throws -> RenderPlan {
        var project = Project(canvas: .portrait)
        project.media[halves.info.id] = halves.info
        for id in 1...2 {
            project.clips.append(Clip(
                id: ClipID(id), media: halves.info.id, sourceStart: .zero, duration: halves.duration,
                framing: Framing(backdrop: backdrop)))
        }
        project.nextClipID = 3
        return try renderPlan(for: project)
    }
}

private let blue = RGB(r: 0, g: 0, b: 255)
private let black = RGB(r: 0, g: 0, b: 0)

/// The frame of a file at 1 second.
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
private func frame(of file: URL) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try await generator.image(at: CMTime(value: 600, timescale: 600)).image
}

/// The bytes of a picture drawn in sRGB, four a pixel, from the top left.
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
private func pixels(of image: CGImage) throws -> (bytes: [UInt8], rowBytes: Int) {
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
    let bytes = Array(UnsafeBufferPointer(start: data, count: context.bytesPerRow * image.height))
    return (bytes, context.bytesPerRow)
}

/// The 10 by 10 square around the point.
private func square(x: Int, y: Int) -> CGRect {
    CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
}

private func share(of colour: RGB, in image: CGImage, x: Int, y: Int) throws -> Double {
    let rect = square(x: x, y: y)
    let read = try pixels(of: image)
    var near = 0
    var all = 0
    for row in Int(rect.minY)..<Int(rect.maxY) {
        for column in Int(rect.minX)..<Int(rect.maxX) {
            let offset = row * read.rowBytes + column * 4
            let worst = max(
                abs(Int(read.bytes[offset]) - Int(colour.r)), abs(Int(read.bytes[offset + 1]) - Int(colour.g)),
                abs(Int(read.bytes[offset + 2]) - Int(colour.b)))
            if worst <= 24 {
                near += 1
            }
            all += 1
        }
    }
    return Double(near) / Double(all)
}

private func mean(in image: CGImage, x: Int, y: Int) throws -> (r: Double, g: Double, b: Double) {
    try mean(in: image, square(x: x, y: y))
}

/// The mean of each channel over the rectangle, 0 to 255.
private func mean(in image: CGImage, _ rect: CGRect) throws -> (r: Double, g: Double, b: Double) {
    let read = try pixels(of: image)
    var sums = (r: 0.0, g: 0.0, b: 0.0)
    var all = 0.0
    for row in Int(rect.minY)..<Int(rect.maxY) {
        for column in Int(rect.minX)..<Int(rect.maxX) {
            let offset = row * read.rowBytes + column * 4
            sums.r += Double(read.bytes[offset])
            sums.g += Double(read.bytes[offset + 1])
            sums.b += Double(read.bytes[offset + 2])
            all += 1
        }
    }
    return (sums.r / all, sums.g / all, sums.b / all)
}
#endif
