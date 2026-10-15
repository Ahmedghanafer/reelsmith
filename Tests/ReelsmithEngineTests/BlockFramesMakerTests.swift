#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The frames of the blocks, made by `makeBlockFrames` from the files of a media folder of their own: blue, turned,
/// the still movie of the magenta photo and a clip of 30 seconds written here. A colour matches within 24 of 255
/// per channel.
final class BlockFramesMakerTests: XCTestCase {
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("reelsmith-block-frames", isDirectory: true)

    /// 1920 by 1080, 30 seconds, green, no sound: a long clip of hers stands in for it.
    static let long = TestClip(
        name: "long", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 18000), framesPerSecond: 30,
        quarterTurns: 0, hasSound: false, left: RGB(r: 0, g: 255, b: 0), right: RGB(r: 0, g: 255, b: 0))

    /// The still movie of the magenta photo, written once for every test that reads it.
    static let photo = Task<MediaInfo, Error> {
        let picture = try writeTestPhoto(.magenta, to: folder)
        let info = TestPhoto.magenta.info
        if FileManager.default.fileExists(atPath: folder.appendingPathComponent(info.fileName).path) {
            return info
        }
        return try await importPhoto(from: picture, id: info.id, into: folder)
    }

    // 1. E24: the seconds, the count and the bytes of the frames of three media, printed. They decide nothing.
    func testE24PrintsTheCostOfTheFramesOfBlueThePhotoAndAClipOf30Seconds() async throws {
        _ = try await writeTestClip(.blue, to: Self.folder)
        _ = try await writeTestClip(Self.long, to: Self.folder)
        let media = [("blue", TestClip.blue.info), ("photo", try await Self.photo.value), ("30 seconds", Self.long.info)]
        for (name, info) in media {
            let started = Date()
            let frames = try await makeBlockFrames(of: info, mediaFolder: Self.folder)
            let seconds = Date().timeIntervalSince(started)
            let bytes = frames.values.reduce(0) { $0 + $1.bytesPerRow * $1.height }
            let sizes = Set(frames.values.map { "\($0.width)x\($0.height)" }).sorted().joined(separator: ",")
            print("E24: \(name) made \(frames.count) frames in \(seconds) seconds, \(bytes) bytes, sizes \(sizes)")
            XCTAssertEqual(Set(frames.keys), Set(BlockFrames.times(of: info)), name)
        }
    }

    // 3. Blue reads blue, at most 168 on its long side.
    func testTheFramesOfBlueAreBlueWithALongSideOfAtMost168() async throws {
        _ = try await writeTestClip(.blue, to: Self.folder)
        let frames = try await makeBlockFrames(of: TestClip.blue.info, mediaFolder: Self.folder)
        XCTAssertEqual(frames.count, 3)
        for (time, image) in frames {
            XCTAssertLessThanOrEqual(max(image.width, image.height), 168, "at \(time.ticks)")
            XCTAssertGreaterThan(try share(of: RGB(r: 0, g: 0, b: 255), in: image, top: 0, bottom: 1), 0.9, "at \(time.ticks)")
        }
    }

    func testThePhotoGivesOneMagentaFrame() async throws {
        let frames = try await makeBlockFrames(of: try await Self.photo.value, mediaFolder: Self.folder)
        XCTAssertEqual(Array(frames.keys), [Time.zero])
        let image = try XCTUnwrap(frames[.zero])
        XCTAssertLessThanOrEqual(max(image.width, image.height), 168)
        XCTAssertGreaterThan(try share(of: RGB(r: 255, g: 0, b: 255), in: image, top: 0, bottom: 1), 0.9)
    }

    /// Turned is stored 1920 by 1080, white left and blue right, and upright 1080 by 1920 with white above blue.
    func testTurnedGivesUprightFramesWhiteAboveBlue() async throws {
        _ = try await writeTestClip(.turned, to: Self.folder)
        let frames = try await makeBlockFrames(of: TestClip.turned.info, mediaFolder: Self.folder)
        XCTAssertEqual(frames.count, 2)
        for (time, image) in frames {
            print("block frames: turned at \(time.ticks) is \(image.width) by \(image.height)")
            XCTAssertLessThan(image.width, image.height, "at \(time.ticks)")
            XCTAssertLessThanOrEqual(image.height, 168, "at \(time.ticks)")
            // The top and the bottom 40 percent, clear of the line where the two halves meet.
            XCTAssertGreaterThan(try share(of: RGB(r: 255, g: 255, b: 255), in: image, top: 0, bottom: 0.4), 0.9)
            XCTAssertGreaterThan(try share(of: RGB(r: 0, g: 0, b: 255), in: image, top: 0.6, bottom: 1), 0.9)
        }
    }
}

/// The share of the pixels of the rows from `top` to `bottom`, as parts of the height counted from the top, within
/// 24 per channel of the colour.
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
private func share(of colour: RGB, in image: CGImage, top: Double, bottom: Double) throws -> Double {
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
    var near = 0
    var all = 0
    // The first row of the bytes is the top row of the picture.
    for y in Int(Double(image.height) * top)..<Int(Double(image.height) * bottom) {
        for x in 0..<image.width {
            let offset = y * context.bytesPerRow + x * 4
            let worst = max(
                abs(Int(bytes[offset]) - Int(colour.r)), abs(Int(bytes[offset + 1]) - Int(colour.g)),
                abs(Int(bytes[offset + 2]) - Int(colour.b)))
            if worst <= 24 {
                near += 1
            }
            all += 1
        }
    }
    return all == 0 ? 0 : Double(near) / Double(all)
}
#endif
