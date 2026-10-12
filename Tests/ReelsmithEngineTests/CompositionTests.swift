#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

final class CompositionTests: XCTestCase {
    /// One folder for the whole run. A clip is written by the first test that asks for it and kept for the rest.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("m1-5-engine-" + UUID().uuidString)

    @MainActor
    func testThePlayerItemOfThreeClipsIs9SecondsLongAndShowsBlueRedGreen() async throws {
        let item = try await threeClipsItem()

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

    /// The test clips are tagged 709 already, so the exported file cannot show that the Engine asks for it.
    @MainActor
    func testThePlayerItemCarriesThe709ColourProperties() async throws {
        let item = try await threeClipsItem()
        let videoComposition = try XCTUnwrap(item.videoComposition)
        XCTAssertEqual(videoComposition.colorPrimaries, AVVideoColorPrimaries_ITU_R_709_2)
        XCTAssertEqual(videoComposition.colorTransferFunction, AVVideoTransferFunction_ITU_R_709_2)
        XCTAssertEqual(videoComposition.colorYCbCrMatrix, AVVideoYCbCrMatrix_ITU_R_709_2)
    }

    /// Blue is one colour and one tone throughout, so only the segments show where in the source a clip starts.
    /// https://developer.apple.com/documentation/avfoundation/avcompositiontrack/segments
    /// https://developer.apple.com/documentation/avfoundation/avassettracksegment/timemapping
    @MainActor
    func testTheSegmentsOfATrimmedPlanHaveTheSourceStartsTheTargetStartsAndTheLengthsOfThePlan() async throws {
        var media: [MediaID: MediaInfo] = [:]
        for clip in [TestClip.blue, TestClip.red, TestClip.green] {
            _ = try await writeTestClip(clip, to: Self.folder)
            media[clip.info.id] = clip.info
        }

        let item = try await makePlayerItem(plan: ExportTests.trimmedPlan, media: media, mediaFolder: Self.folder)

        let composition = try XCTUnwrap(item.asset as? AVComposition)
        let pictureTracks = composition.tracks.filter { $0.mediaType == .video }
        let soundTracks = composition.tracks.filter { $0.mediaType == .audio }
        XCTAssertEqual(pictureTracks.count, 1)
        XCTAssertEqual(soundTracks.count, 1)

        let picture = try XCTUnwrap(pictureTracks.first).segments
        XCTAssertEqual(picture.map { $0.isEmpty }, [false, false, false])
        XCTAssertEqual(picture.map { $0.timeMapping.source.start }, [ticks(600), ticks(0), ticks(0)])
        XCTAssertEqual(picture.map { $0.timeMapping.source.duration }, [ticks(1200), ticks(1200), ticks(1200)])
        XCTAssertEqual(picture.map { $0.timeMapping.target.start }, [ticks(0), ticks(1200), ticks(2400)])
        XCTAssertEqual(picture.map { $0.timeMapping.target.duration }, [ticks(1200), ticks(1200), ticks(1200)])

        let sound = try XCTUnwrap(soundTracks.first).segments
        XCTAssertEqual(sound.map { $0.isEmpty }, [false, false])
        XCTAssertEqual(sound.map { $0.timeMapping.source.start }, [ticks(600), ticks(0)])
        XCTAssertEqual(sound.map { $0.timeMapping.source.duration }, [ticks(1200), ticks(1200)])
        XCTAssertEqual(sound.map { $0.timeMapping.target.start }, [ticks(0), ticks(1200)])
        XCTAssertEqual(sound.map { $0.timeMapping.target.duration }, [ticks(1200), ticks(1200)])
    }

    private func ticks(_ value: Int64) -> CMTime {
        CMTime(value: value, timescale: 600)
    }

    @MainActor
    private func threeClipsItem() async throws -> AVPlayerItem {
        for clip in Seed.threeClips.testClips {
            _ = try await writeTestClip(clip, to: Self.folder)
        }
        let project = Seed.threeClips.project
        let plan = try renderPlan(for: project)
        return try await makePlayerItem(plan: plan, media: project.media, mediaFolder: Self.folder)
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

/// A colour matches within 24 of 255 per channel.
private func assertNear(_ colour: RGB, _ wanted: RGB, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(Int(colour.r) - Int(wanted.r)), 24, what + " red", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.g) - Int(wanted.g)), 24, what + " green", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.b) - Int(wanted.b)), 24, what + " blue", file: file, line: line)
}
#endif
