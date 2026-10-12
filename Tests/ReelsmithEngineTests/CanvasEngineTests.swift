#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The landscape canvas through the Engine. The clips and the exported files go into the folder of `ExportTests`.
final class CanvasEngineTests: XCTestCase {
    /// The export of the plan of two-clips-wide, made once for the tests that read it.
    static let twoClipsWide = Task<ExportTests.Exported, Error> {
        let plan = try renderPlan(for: Seed.twoClipsWide.project)
        return try await ExportTests.exported(plan, clips: Seed.twoClipsWide.testClips, name: "two-clips-wide.out")
    }

    func testTheWideSeedExportsToOneMPEG4FileOf1920By1080With210FramesIn7Seconds() async throws {
        let made = try await Self.twoClipsWide.value
        let file = made.file
        XCTAssertEqual(try fileType(of: made.output), "mp42")

        let all = try await tracks(of: file)
        let picture = all.filter { $0.kind == "vide" }
        let sound = all.filter { $0.kind == "soun" }
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(picture.count, 1)
        XCTAssertEqual(picture.first?.coding, "avc1")
        XCTAssertEqual(picture.first?.duration, CMTime(value: 4200, timescale: 600))
        XCTAssertEqual(sound.count, 1)
        XCTAssertEqual(sound.first?.coding, "aac ")

        let size = try await storedSize(of: file)
        XCTAssertEqual(size.width, 1920)
        XCTAssertEqual(size.height, 1080)
        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 210)
    }

    func testInTheWideExportBlueFillsTheCanvasAndRedStandsWholeWithABarLeftAndRight() async throws {
        let file = try await Self.twoClipsWide.value.file
        let blue = RGB(r: 0, g: 0, b: 255)
        let red = RGB(r: 255, g: 0, b: 0)
        let black = RGB(r: 0, g: 0, b: 0)
        let checks: [(Int64, Int, Int, RGB)] = [
            (600, 960, 540, blue), (600, 100, 540, blue), (600, 1820, 540, blue),
            (3000, 960, 540, red), (3000, 960, 100, red), (3000, 960, 980, red), (3000, 700, 540, red),
            (3000, 100, 540, black), (3000, 620, 540, black), (3000, 1820, 540, black),
        ]
        for (ticks, x, y, wanted) in checks {
            let colour = try await pixel(of: file, at: Time(ticks: ticks), x: x, y: y)
            assertNear(colour, wanted, "(\(x), \(y)) at \(ticks) ticks")
        }
    }

    func testTheTurnedClipOnTheLandscapeCanvasExportsUprightInTheMiddle() async throws {
        let turned = TestClip.turned
        var project = Project(canvas: .landscape)
        project.media[turned.info.id] = turned.info
        project.clips = [Clip(id: ClipID(1), media: turned.info.id, sourceStart: .zero, duration: turned.duration)]
        let plan = try renderPlan(for: project)
        let file = try await ExportTests.exported(plan, clips: [turned], name: "turned-wide.out").file

        let size = try await storedSize(of: file)
        XCTAssertEqual(size.width, 1920)
        XCTAssertEqual(size.height, 1080)
        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 60)
        let top = try await pixel(of: file, at: Time(ticks: 600), x: 960, y: 200)
        let bottom = try await pixel(of: file, at: Time(ticks: 600), x: 960, y: 880)
        let beside = try await pixel(of: file, at: Time(ticks: 600), x: 300, y: 540)
        assertNear(top, RGB(r: 255, g: 255, b: 255), "(960, 200) at 1.0")
        assertNear(bottom, RGB(r: 0, g: 0, b: 255), "(960, 880) at 1.0")
        assertNear(beside, RGB(r: 0, g: 0, b: 0), "(300, 540) at 1.0")
    }

    /// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
    /// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
    /// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
    @MainActor
    func testAFrameOfThePlayerItemOfTheWideSeedIs1920By1080WithABlueMiddle() async throws {
        for clip in Seed.twoClipsWide.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        let project = Seed.twoClipsWide.project
        let plan = try renderPlan(for: project)
        let item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: ExportTests.folder)

        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.videoComposition = item.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(value: 600, timescale: 600)).image
        XCTAssertEqual(image.width, 1920)
        XCTAssertEqual(image.height, 1080)

        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (image.height / 2) * context.bytesPerRow + (image.width / 2) * 4
        let middle = RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
        assertNear(middle, RGB(r: 0, g: 0, b: 255), "middle at 1.0")
    }
}

/// A colour matches within 24 of 255 per channel.
private func assertNear(_ colour: RGB, _ wanted: RGB, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(Int(colour.r) - Int(wanted.r)), 24, what + " red", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.g) - Int(wanted.g)), 24, what + " green", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.b) - Int(wanted.b)), 24, what + " blue", file: file, line: line)
}
#endif
