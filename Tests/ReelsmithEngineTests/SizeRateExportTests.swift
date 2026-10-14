#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import XCTest

// The picture of a text layer is internal to the Engine.
@testable import ReelsmithEngine

/// Exports at a size and a rate: every plan is made by `renderPlan(for:settings:)` from a project built in the test
/// and written by `export`. Sizes, rates and frames are read from the file with `readVideoFacts` and the helpers of
/// `MediaReading.swift`, and a place is counted in the pixels of the file. A frame of a file at 60 is read at its
/// middle, 10 times n plus 5 ticks. Every export prints one line that starts with `size-rate:`.
/// The clips and the exported files go into the folder of `ExportTests`.
///
/// Numbers named "printed by the trial" were printed by the export trial in compile check run 38528134806 on
/// head 94642eb.
final class SizeRateExportTests: XCTestCase {
    // MARK: 720p

    func testTwoClipsWideAt720And30Is1280By720With210FramesAndTheRedClipBetweenItsBars() async throws {
        let made = try await exported(Seed.twoClipsWide.project, clips: Seed.twoClipsWide.testClips,
                                      settings: ExportSettings(size: .hd720, rate: .thirty), name: "wide-720-30")
        XCTAssertEqual(made.facts.infoText, "1280 720 30")
        XCTAssertEqual(made.frames, 210)
        let all = try await tracks(of: made.file)
        XCTAssertEqual(all.filter { $0.kind == "vide" }.count, 1)
        let sound = all.filter { $0.kind == "soun" }
        XCTAssertEqual(sound.count, 1)
        XCTAssertEqual(sound.first?.coding, "aac ")

        let checks: [(Int64, Int, Int, RGB)] = [
            (600, 640, 360, blue), (3000, 640, 360, red),
            (3000, 67, 360, black), (3000, 413, 360, black), (3000, 1213, 360, black),
        ]
        for (ticks, x, y, wanted) in checks {
            let colour = try await read(made, at: ticks, x: x, y: y)
            assertNear(colour, wanted, "(\(x), \(y)) at \(ticks) ticks")
        }
    }

    // MARK: 1080p

    /// Printed by the trial for the blink clip at 1920 by 1080 and one sixtieth: `1920 1080 60`, 60 frames, red and
    /// blue in turn at the middle of frames 0 to 5.
    func testTheBlinkClipAt1080And60Has60FramesOfRedThenBlue() async throws {
        let project = try await blinkProject()
        let made = try await exported(project, settings: ExportSettings(size: .hd1080, rate: .sixty),
                                      name: "blink-1080-60")
        XCTAssertEqual(made.facts.infoText, "1920 1080 60")
        XCTAssertEqual(made.frames, 60)
        for n in 0..<6 {
            let colour = try await read(made, at: 10 * Int64(n) + 5, x: 960, y: 540)
            assertNear(colour, n % 2 == 0 ? BlinkClip.even : BlinkClip.odd, "(960, 540) in the middle of frame \(n)")
        }
    }

    /// At 30 the size, the rate and the count of frames are asserted, and no colour of a frame.
    func testTheBlinkClipAt1080And30Has30Frames() async throws {
        let project = try await blinkProject()
        let made = try await exported(project, settings: ExportSettings(size: .hd1080, rate: .thirty),
                                      name: "blink-1080-30")
        XCTAssertEqual(made.facts.infoText, "1920 1080 30")
        XCTAssertEqual(made.frames, 30)
    }

    /// Printed by the trial for `blue`, a source of 30, cut to 600 ticks at 1920 by 1080 and one sixtieth:
    /// `1920 1080 60` and 60 frames. For the three seconds of `blue` that is 180 frames.
    func testBlueASourceOf30At1080And60Has180FramesAndItsSoundAsBefore() async throws {
        var project = Project(canvas: .landscape)
        project.media[TestClip.blue.info.id] = TestClip.blue.info
        project.clips = [Clip(id: ClipID(1), media: TestClip.blue.info.id, sourceStart: .zero,
                              duration: TestClip.blue.duration)]
        project.nextClipID = 2
        let made = try await exported(project, clips: [.blue], settings: ExportSettings(size: .hd1080, rate: .sixty),
                                      name: "blue-1080-60")
        XCTAssertEqual(made.facts.infoText, "1920 1080 60")
        XCTAssertEqual(made.frames, 180)
        let middle = try await read(made, at: 600, x: 960, y: 540)
        assertNear(middle, blue, "(960, 540) at 1.0 second")
        let level = try await toneLevel(of: made.file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        XCTAssertLessThanOrEqual(abs(level - 0.5), 0.15 * 0.5, "440 Hz reads \(level), expected 0.5")
    }

    // MARK: 4K

    /// The time limit is three times the 1.46 seconds printed by the trial for one second of the blink clip at
    /// 3840 by 2160 and one sixtieth with the HEVC highest quality preset, and never below 30 seconds.
    func testOneSecondOfBlueAt4KAnd60Is3840By2160With60FramesInHEVC() async throws {
        let made = try await exported(try oneSecondOfBlue(), clips: [.blue],
                                      settings: ExportSettings(size: .uhd4K, rate: .sixty), name: "blue-4k-60")
        XCTAssertEqual(made.facts.infoText, "3840 2160 60")
        XCTAssertEqual(made.frames, 60)
        XCTAssertEqual(made.coding, "hvc1")
        for (x, y) in [(1920, 1080), (100, 100), (3740, 2060)] {
            let colour = try await read(made, at: 300, x: x, y: y)
            assertNear(colour, blue, "(\(x), \(y)) at 300 ticks")
        }
        let limit = max(3 * 1.46, 30)
        print("size-rate: one second of blue at 3840 by 2160 and 60 took \(made.seconds) seconds, limit \(limit)")
        XCTAssertLessThanOrEqual(made.seconds, limit)
    }

    /// The text of `text-box-wide` for the whole of one second of blue, at 3840 by 2160 and 30.
    func testTheBoxedTextAt4KIsDrawnAtTwiceItsSizeOverBlue() async throws {
        var project = try oneSecondOfBlue()
        var text = try XCTUnwrap(Seed.textBoxWide.project.texts.first)
        text.span = .whole
        project.texts = [text]
        project.nextTextID = 2
        let settings = ExportSettings(size: .uhd4K, rate: .thirty)
        let made = try await exported(project, clips: [.blue], settings: settings, name: "box-4k-30")
        XCTAssertEqual(made.facts.infoText, "3840 2160 30")

        let layer = try XCTUnwrap(try renderPlan(for: project, settings: settings).texts.first)
        let picture = try XCTUnwrap(textPicture(for: layer))
        let corner = (x: Int(layer.x - picture.width / 2 + 10), y: Int(layer.y - picture.height / 2 + 10))
        let left = Int(layer.x - picture.width / 2) - 20
        let box = try await read(made, at: 300, x: corner.x, y: corner.y)
        assertNear(box, boxOverBlue, "the box corner (\(corner.x), \(corner.y)) at 300 ticks")
        let beside = try await read(made, at: 300, x: left, y: corner.y)
        assertNear(beside, blue, "(\(left), \(corner.y)), 20 pixels left of the box, at 300 ticks")

        let standard = try XCTUnwrap(try renderPlan(for: project).texts.first)
        let small = try XCTUnwrap(textPicture(for: standard))
        print("size-rate: the text picture is \(picture.width) wide at 3840 by 2160 and \(small.width) at standard")
        XCTAssertLessThanOrEqual(abs(picture.width - 2 * small.width), 4)
    }

    /// Printed by the trial for one second of the blink clip on the portrait shape at 2160 by 3840 and one sixtieth
    /// with the HEVC highest quality preset: `2160 3840 60`, 60 frames.
    func testOneSecondOfBlueOnThePortraitCanvasAt4KAnd60Is2160By3840With60Frames() async throws {
        var project = try oneSecondOfBlue()
        project.canvas = .portrait
        let made = try await exported(project, clips: [.blue], settings: ExportSettings(size: .uhd4K, rate: .sixty),
                                      name: "blue-portrait-4k-60")
        XCTAssertEqual(made.facts.infoText, "2160 3840 60")
        XCTAssertEqual(made.frames, 60)
    }

    // MARK: The preview

    /// https://developer.apple.com/documentation/avfoundation/avvideocomposition/rendersize
    /// https://developer.apple.com/documentation/avfoundation/avvideocomposition/frameduration
    /// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
    @MainActor
    func testThePlayerItemOfTwoClipsWideIs1920By1080At30WithABlueMiddle() async throws {
        for clip in Seed.twoClipsWide.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        let project = Seed.twoClipsWide.project
        let item = try await makePlayerItem(
            plan: try renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
        let composition = try XCTUnwrap(item.videoComposition)
        XCTAssertEqual(composition.renderSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(composition.frameDuration, CMTime(value: 1, timescale: 30))

        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.videoComposition = composition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(value: 600, timescale: 600)).image
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (image.height / 2) * context.bytesPerRow + (image.width / 2) * 4
        assertNear(RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2]), blue, "middle at 1.0")
    }

    // MARK: Helpers

    struct Made {
        var file: URL
        var facts: VideoFacts
        var frames: Int
        var coding: String
        var seconds: Double
    }

    /// Writes the test clips, exports the plan of the project at the settings to `<name>.mp4` and prints one line
    /// that starts with `size-rate:`.
    private func exported(_ project: Project, clips: [TestClip] = [], settings: ExportSettings,
                          name: String) async throws -> Made {
        for clip in clips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        let plan = try renderPlan(for: project, settings: settings)
        let output = ExportTests.folder.appendingPathComponent("size-rate-\(name).mp4")
        let began = Date()
        try await export(plan: plan, media: project.media, mediaFolder: ExportTests.folder, to: output) { _ in }
        let seconds = Date().timeIntervalSince(began)

        let facts = try await readVideoFacts(of: output)
        let frames = try await frameCount(of: output)
        let coding = try await tracks(of: output).first { $0.kind == "vide" }?.coding ?? "none"
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        print("size-rate: \(name) asked \(plan.width) by \(plan.height) at \(plan.framesPerSecond), "
            + "facts \(facts.infoText), \(frames) frames, coding \(coding), \(bytes) bytes, "
            + String(format: "%.2f", seconds) + " seconds")
        return Made(file: output, facts: facts, frames: frames, coding: coding, seconds: seconds)
    }

    /// A landscape project of the blink clip whole, the clip written.
    private func blinkProject() async throws -> Project {
        let info = try await writeBlinkClip(to: ExportTests.folder)
        var project = Project(canvas: .landscape)
        project.media[info.id] = info
        project.clips = [Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: info.duration)]
        project.nextClipID = 2
        return project
    }

    /// A landscape project of the clip `blue` from its first frame for 600 ticks.
    private func oneSecondOfBlue() throws -> Project {
        var project = Project(canvas: .landscape)
        project.media[TestClip.blue.info.id] = TestClip.blue.info
        project.clips = [Clip(id: ClipID(1), media: TestClip.blue.info.id, sourceStart: .zero,
                              duration: Time(ticks: 600))]
        project.nextClipID = 2
        return project
    }

    /// `pixel(of:at:x:y:)`, but a place outside the stored picture fails the test instead of being read.
    private func read(_ made: Made, at ticks: Int64, x: Int, y: Int) async throws -> RGB {
        guard x >= 0, y >= 0, x < made.facts.width, y < made.facts.height else {
            XCTFail("(\(x), \(y)) lies outside the stored picture of \(made.facts.width) by \(made.facts.height)")
            throw EngineError.cannotRead
        }
        return try await pixel(of: made.file, at: Time(ticks: ticks), x: x, y: y)
    }
}

private let blue = RGB(r: 0, g: 0, b: 255)
private let red = RGB(r: 255, g: 0, b: 0)
private let black = RGB(r: 0, g: 0, b: 0)
/// The box is black at 60 percent, so over blue it reads blue times 0.4.
private let boxOverBlue = RGB(r: 0, g: 0, b: 102)

/// A colour matches within 24 of 255 per channel.
private func assertNear(_ colour: RGB, _ wanted: RGB, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
    let read = " reads \(colour.r), \(colour.g), \(colour.b)"
    XCTAssertLessThanOrEqual(abs(Int(colour.r) - Int(wanted.r)), 24, what + read + " red", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.g) - Int(wanted.g)), 24, what + read + " green", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.b) - Int(wanted.b)), 24, what + read + " blue", file: file, line: line)
}
#endif
