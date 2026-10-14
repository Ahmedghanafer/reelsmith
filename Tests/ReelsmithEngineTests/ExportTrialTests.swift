#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import XCTest

// The builder of the composition is internal to the Engine.
@testable import ReelsmithEngine

/// The facts of a written video, the blink clip, and the trial: the product's own builder on the plan of the
/// blink clip whole on the landscape canvas, with the render size and the frame duration of its video composition
/// set by the test, exported with the preset and the file type of `export`. Only the render size changes, so the
/// picture is drawn in the 1920 by 1080 rectangle at the bottom left of the frame, and every pixel read lies in it.
/// A frame of a file at 60 is read at its middle, 10 times n plus 5 ticks, and at 30 at 20 times n plus 5.
/// The clips and the exported files go into the folder of `ExportTests`.
final class ExportTrialTests: XCTestCase {
    // MARK: The facts of a file

    func testTheFactsOfBlueRead1920By1080At30AndOfFast1080By1920At60() async throws {
        let blue = try await writeTestClip(.blue, to: ExportTests.folder)
        let fast = try await writeTestClip(.fast, to: ExportTests.folder)
        let blueFacts = try await readVideoFacts(of: blue)
        let fastFacts = try await readVideoFacts(of: fast)
        XCTAssertEqual(blueFacts, VideoFacts(width: 1920, height: 1080, framesPerSecond: 30))
        XCTAssertEqual(blueFacts.infoText, "1920 1080 30")
        XCTAssertEqual(fastFacts.infoText, "1080 1920 60")
    }

    func testAToneWithNoPictureThrowsCannotRead() async throws {
        let tone = try await writeTestTone(.long, to: ExportTests.folder)
        do {
            _ = try await readVideoFacts(of: tone)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
    }

    // MARK: The blink clip

    func testTheBlinkClipIs1920By1080With60FramesOfRedThenBlueAndASecondCallKeepsIt() async throws {
        let info = try await writeBlinkClip(to: ExportTests.folder)
        XCTAssertEqual(info, MediaInfo(
            id: MediaID("blink"), fileName: "blink.mov", width: 1920, height: 1080, duration: Time(ticks: 600),
            quarterTurns: 0, hasSound: false))
        let file = ExportTests.folder.appendingPathComponent("blink.mov")
        let size = try await storedSize(of: file)
        XCTAssertEqual(size.width, 1920)
        XCTAssertEqual(size.height, 1080)
        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 60)
        let facts = try await readVideoFacts(of: file)
        XCTAssertEqual(facts.infoText, "1920 1080 60")
        try await assertBlinks(file, frameTicks: 10, x: 960, y: 540)

        let before = try modified(file)
        let again = try await writeBlinkClip(to: ExportTests.folder)
        XCTAssertEqual(again, info)
        XCTAssertEqual(try modified(file), before)
    }

    // MARK: The trial (E12 and E13)

    func testTheTrialAt1280By720At60WritesThatSizeAnd60FramesOfRedThenBlue() async throws {
        let made = try await trial(width: 1280, height: 720, rate: 60)
        XCTAssertEqual(made.facts.infoText, "1280 720 60")
        XCTAssertEqual(made.frames, 60)
        try await assertBlinks(made.file, frameTicks: 10, x: 640, y: 360)
    }

    func testTheTrialAt3840By2160At60WritesThatSizeAnd60FramesOfRedThenBlue() async throws {
        let made = try await trial(width: 3840, height: 2160, rate: 60)
        XCTAssertEqual(made.facts.infoText, "3840 2160 60")
        XCTAssertEqual(made.frames, 60)
        try await assertBlinks(made.file, frameTicks: 10, x: 960, y: 1620)
    }

    func testTheTrialAt1920By1080At30KeepsTheEvenFramesOnly() async throws {
        let made = try await trial(width: 1920, height: 1080, rate: 30)
        XCTAssertEqual(made.facts.infoText, "1920 1080 30")
        XCTAssertEqual(made.frames, 30)
        for n in 0..<6 {
            let colour = try await pixel(of: made.file, at: Time(ticks: 20 * Int64(n) + 5), x: 960, y: 540)
            assertNear(colour, BlinkClip.even, "(960, 540) in the middle of frame \(n) of 30")
        }
    }

    /// E13: printed, never asserted.
    func testTheTrialAt2160By3840At60PrintsWhatItWrote() async {
        do {
            _ = try await trial(width: 2160, height: 3840, rate: 60)
        } catch {
            print("export-trial: 2160 by 3840 at 60 threw \(error)")
        }
    }

    // MARK: Helpers

    struct Trial {
        var file: URL
        var facts: VideoFacts
        var frames: Int
    }

    /// Exports the blink clip as the trial does and prints one line that starts with `export-trial:`.
    /// https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition/rendersize
    /// https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition/frameduration
    /// https://developer.apple.com/documentation/avfoundation/avassetexportsession
    /// https://developer.apple.com/documentation/avfoundation/avassetexportpresethighestquality
    /// https://developer.apple.com/documentation/avfoundation/avassetexportsession/exportasynchronously(completionhandler:)
    private func trial(width: Int, height: Int, rate: Int32) async throws -> Trial {
        let info = try await writeBlinkClip(to: ExportTests.folder)
        var project = Project(canvas: .landscape)
        project.media[info.id] = info
        project.clips.append(Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: info.duration))
        project.nextClipID = 2
        let plan = try renderPlan(for: project)

        let built = try await buildComposition(plan: plan, media: project.media, mediaFolder: ExportTests.folder)
        built.videoComposition.renderSize = CGSize(width: width, height: height)
        built.videoComposition.frameDuration = CMTime(value: 1, timescale: rate)
        let session = try XCTUnwrap(
            AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetHighestQuality))
        let output = ExportTests.folder.appendingPathComponent("trial-\(width)-\(height)-\(rate).mp4")
        try? FileManager.default.removeItem(at: output)
        session.videoComposition = built.videoComposition
        session.audioMix = built.audioMix
        session.outputFileType = .mp4
        session.outputURL = output

        let began = Date()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                done.resume()
            }
        }
        let seconds = Date().timeIntervalSince(began)
        let asked = "\(width) by \(height) at \(rate)"
        guard session.status == .completed else {
            let error = session.error.map { String(describing: $0) } ?? "none"
            print("export-trial: \(asked) asked, status \(session.status.rawValue) after "
                + String(format: "%.2f", seconds) + " seconds, error \(error)")
            throw session.error ?? EngineError.cannotWrite
        }

        let facts = try await readVideoFacts(of: output)
        let frames = try await frameCount(of: output)
        let coding = try await tracks(of: output).first { $0.kind == "vide" }?.coding ?? "none"
        var profile = "no profile or level (not H.264)"
        if let h264 = try await profileAndLevel(of: output) {
            profile = "profile \(h264.profile), level \(h264.level)"
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        print("export-trial: \(asked) asked, stored \(facts.width) by \(facts.height), facts \(facts.infoText), "
            + "\(frames) frames, coding \(coding), \(profile), \(bytes) bytes, "
            + String(format: "%.2f", seconds) + " seconds")
        return Trial(file: output, facts: facts, frames: frames)
    }

    /// Red, blue, red, blue, red, blue at the middle of frames 0 to 5.
    private func assertBlinks(
        _ file: URL, frameTicks: Int64, x: Int, y: Int, line: UInt = #line
    ) async throws {
        for n in 0..<6 {
            let colour = try await pixel(of: file, at: Time(ticks: frameTicks * Int64(n) + 5), x: x, y: y)
            let wanted = n % 2 == 0 ? BlinkClip.even : BlinkClip.odd
            assertNear(colour, wanted, "(\(x), \(y)) in the middle of frame \(n)", line: line)
        }
    }

    /// The profile and the level in the H.264 configuration of the picture track, nil when it has none.
    /// https://developer.apple.com/documentation/coremedia/kcmformatdescriptionextension_sampledescriptionextensionatoms
    private func profileAndLevel(of file: URL) async throws -> (profile: Int, level: Int)? {
        let asset = AVURLAsset(url: file)
        let pictureTracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(pictureTracks.first)
        let descriptions = try await track.load(.formatDescriptions)
        let description = try XCTUnwrap(descriptions.first)
        let atoms = CMFormatDescriptionGetExtension(
            description, extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms) as? [String: Any]
        guard let configuration = atoms?["avcC"] as? Data else { return nil }
        let bytes = [UInt8](configuration)
        guard bytes.count > 3 else { return nil }
        return (Int(bytes[1]), Int(bytes[3]))
    }

    private func modified(_ file: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        return try XCTUnwrap(attributes[.modificationDate] as? Date)
    }
}

/// A colour matches within 24 of 255 per channel.
private func assertNear(_ colour: RGB, _ wanted: RGB, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
    let read = " reads \(colour.r), \(colour.g), \(colour.b)"
    XCTAssertLessThanOrEqual(abs(Int(colour.r) - Int(wanted.r)), 24, what + read + " red", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.g) - Int(wanted.g)), 24, what + read + " green", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.b) - Int(wanted.b)), 24, what + read + " blue", file: file, line: line)
}
#endif
