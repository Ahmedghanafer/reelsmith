#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

final class CompositionTests: XCTestCase {
    // Criterion 6
    @MainActor
    func testThePlayerItemOfThreeClipsIs9SecondsLongAndShowsBlueRedGreen() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("m1-5-engine-" + UUID().uuidString)
        for clip in Seed.threeClips.testClips {
            _ = try await writeTestClip(clip, to: folder)
        }
        let project = Seed.threeClips.project
        let plan = try renderPlan(for: project)

        let item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: folder)

        let length = try await item.asset.load(.duration)
        XCTAssertEqual(length, CMTime(value: 5400, timescale: 600), "\(length.seconds)")

        // https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.videoComposition = item.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let checks: [(Int64, RGB, String)] = [
            (600, RGB(r: 0, g: 0, b: 255), "middle at 1.0"), (3000, RGB(r: 255, g: 0, b: 0), "middle at 5.0"),
            (4800, RGB(r: 0, g: 255, b: 0), "middle at 8.0"),
        ]
        for (ticks, wanted, what) in checks {
            let image = try await generator.image(at: CMTime(value: ticks, timescale: 600)).image
            XCTAssertEqual(image.width, 1080, what)
            XCTAssertEqual(image.height, 1920, what)
            let colour = try middlePixel(of: image)
            assertNear(colour, wanted, what)
        }
    }

    /// The colour of the pixel in the middle of a picture.
    /// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
    private func middlePixel(of image: CGImage) throws -> RGB {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (image.height / 2) * context.bytesPerRow + (image.width / 2) * 4
        return RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
    }
}
#endif
