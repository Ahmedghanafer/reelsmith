#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

final class ExportTests: XCTestCase {
    /// One folder for the whole run: the test clips and the exported files.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("m1-5-engine-" + UUID().uuidString)

    struct Exported {
        /// The output place, whose name does not end in mp4.
        var output: URL
        /// A copy of it for the helpers.
        var file: URL
        var progress: [Double]
        var seconds: Double
    }

    /// The export of the plan of three-clips, made once for the tests that read it.
    static let threeClips = Task<Exported, Error> {
        let plan = try renderPlan(for: Seed.threeClips.project)
        return try await ExportTests.exported(plan, clips: Seed.threeClips.testClips, name: "three-clips.out")
    }

    /// Writes the clips, puts an old file at the output place and exports the plan over it.
    static func exported(_ plan: RenderPlan, clips: [TestClip], name: String) async throws -> Exported {
        var media: [MediaID: MediaInfo] = [:]
        for clip in clips {
            _ = try await writeTestClip(clip, to: folder)
            media[clip.info.id] = clip.info
        }
        let output = folder.appendingPathComponent(name)
        try Data("old".utf8).write(to: output)
        let recorder = ProgressRecorder()
        let began = Date()
        try await export(plan: plan, media: media, mediaFolder: folder, to: output) { value in
            recorder.add(value)
        }
        let seconds = Date().timeIntervalSince(began)
        // The platform picks its file reader by the end of the name, so the helpers read a copy named as MPEG-4.
        let copy = folder.appendingPathComponent(name + ".mp4")
        try FileManager.default.copyItem(at: output, to: copy)
        return Exported(output: output, file: copy, progress: recorder.values, seconds: seconds)
    }

    // Criterion 1
    func testThreeClipsExportIsOneMPEG4FileOf1080By1920With270FramesIn9Seconds() async throws {
        let made = try await Self.threeClips.value
        let file = made.file
        XCTAssertEqual(try fileType(of: made.output), "mp42")

        let all = try await tracks(of: file)
        let picture = all.filter { $0.kind == "vide" }
        let sound = all.filter { $0.kind == "soun" }
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(picture.count, 1)
        XCTAssertEqual(picture.first?.coding, "avc1")
        XCTAssertEqual(picture.first?.duration, CMTime(value: 5400, timescale: 600))
        XCTAssertEqual(sound.count, 1)
        XCTAssertEqual(sound.first?.coding, "aac ")

        let size = try await storedSize(of: file)
        XCTAssertEqual(size.width, 1080)
        XCTAssertEqual(size.height, 1920)
        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 270)
    }

    // Criterion 2
    func testThreeClipsExportIsBlueThenRedThenGreenWithBarsAroundBlue() async throws {
        let file = try await Self.threeClips.value.file
        let blue = try await pixel(of: file, at: Time(ticks: 600), x: 540, y: 960)
        let red = try await pixel(of: file, at: Time(ticks: 3000), x: 540, y: 960)
        let green = try await pixel(of: file, at: Time(ticks: 4800), x: 540, y: 960)
        assertNear(blue, RGB(r: 0, g: 0, b: 255), "middle at 1.0")
        assertNear(red, RGB(r: 255, g: 0, b: 0), "middle at 5.0")
        assertNear(green, RGB(r: 0, g: 255, b: 0), "middle at 8.0")

        let above = try await pixel(of: file, at: Time(ticks: 600), x: 540, y: 100)
        let below = try await pixel(of: file, at: Time(ticks: 600), x: 540, y: 1820)
        assertNear(above, RGB(r: 0, g: 0, b: 0), "above at 1.0")
        assertNear(below, RGB(r: 0, g: 0, b: 0), "below at 1.0")
    }

    // Criterion 3
    func testThreeClipsExportHasSoundThatEndsWithTheLastClipThatHasIt() async throws {
        let file = try await Self.threeClips.value.file
        let sound = try await tracks(of: file).filter { $0.kind == "soun" }
        XCTAssertEqual(sound.first?.duration, CMTime(value: 4200, timescale: 600), "\(String(describing: sound.first?.duration.seconds))")
        let peak = try await soundPeak(of: file, upTo: Time(ticks: 4200))
        XCTAssertGreaterThan(peak, 0.1)
    }

    // Criterion 4
    func testAPlanWithATrimmedStartExportsTheRightFramesAndSound() async throws {
        let whole = Placement(quarterTurns: 0, x: 0, y: 0, width: 1080, height: 1920)
        let wide = Placement(quarterTurns: 0, x: 0, y: 656.25, width: 1080, height: 607.5)
        let plan = RenderPlan(
            segments: [
                Segment(
                    clip: ClipID(1), media: MediaID("blue"), sourceStart: Time(ticks: 600), timelineStart: .zero,
                    duration: Time(ticks: 1200), placement: wide, hasSound: true),
                Segment(
                    clip: ClipID(2), media: MediaID("red"), sourceStart: .zero, timelineStart: Time(ticks: 1200),
                    duration: Time(ticks: 1200), placement: whole, hasSound: true),
                Segment(
                    clip: ClipID(3), media: MediaID("green"), sourceStart: .zero, timelineStart: Time(ticks: 2400),
                    duration: Time(ticks: 1200), placement: whole, hasSound: false),
            ],
            duration: Time(ticks: 3600))
        let file = try await Self.exported(plan, clips: [.blue, .red, .green], name: "trimmed.out").file

        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 180)
        let all = try await tracks(of: file)
        XCTAssertEqual(all.first { $0.kind == "vide" }?.duration, CMTime(value: 3600, timescale: 600))

        let blue = RGB(r: 0, g: 0, b: 255)
        let red = RGB(r: 255, g: 0, b: 0)
        let green = RGB(r: 0, g: 255, b: 0)
        let checks: [(Int64, RGB, String)] = [
            (1160, blue, "2 frames before 2.0"), (1240, red, "2 frames after 2.0"),
            (2360, red, "2 frames before 4.0"), (2440, green, "2 frames after 4.0"),
        ]
        for (ticks, wanted, what) in checks {
            let colour = try await pixel(of: file, at: Time(ticks: ticks), x: 540, y: 960)
            assertNear(colour, wanted, what)
        }

        let sound = all.first { $0.kind == "soun" }
        XCTAssertEqual(sound?.duration, CMTime(value: 2400, timescale: 600), "\(String(describing: sound?.duration.seconds))")
        let peak = try await soundPeak(of: file, upTo: Time(ticks: 2100))
        XCTAssertGreaterThan(peak, 0.1)
    }

    // Criterion 5
    func testTheTurnedClipExportsUprightWithWhiteAboveBlue() async throws {
        let plan = try planOfOne(.turned)
        let file = try await Self.exported(plan, clips: [.turned], name: "turned.out").file

        let size = try await storedSize(of: file)
        XCTAssertEqual(size.width, 1080)
        XCTAssertEqual(size.height, 1920)
        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 60)
        let top = try await pixel(of: file, at: Time(ticks: 600), x: 540, y: 200)
        let bottom = try await pixel(of: file, at: Time(ticks: 600), x: 540, y: 1700)
        assertNear(top, RGB(r: 255, g: 255, b: 255), "(540, 200) at 1.0")
        assertNear(bottom, RGB(r: 0, g: 0, b: 255), "(540, 1700) at 1.0")
    }

    // Criterion 5
    func testTheFastClipExportsTo60FramesIn2Seconds() async throws {
        let plan = try planOfOne(.fast)
        let file = try await Self.exported(plan, clips: [.fast], name: "fast.out").file

        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 60)
        let picture = try await tracks(of: file).first { $0.kind == "vide" }
        XCTAssertEqual(picture?.duration, CMTime(value: 1200, timescale: 600))
        let middle = try await pixel(of: file, at: Time(ticks: 600), x: 540, y: 960)
        assertNear(middle, RGB(r: 255, g: 255, b: 0), "middle at 1.0")
    }

    // Criterion 7
    func testTheExportedPictureReportsThe709ColourPropertiesAt8Bit() async throws {
        let file = try await Self.threeClips.value.file
        let colour = try await colourProperties(of: file)
        XCTAssertEqual(colour.primaries, kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String)
        XCTAssertEqual(colour.transfer, kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String)
        XCTAssertEqual(colour.matrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String)

        // The H.264 profiles 66, 77 and 100 (baseline, main, high) hold 8 bit pictures only.
        let profile = try await h264Profile(of: file)
        XCTAssertTrue([66, 77, 100].contains(profile), "profile \(profile)")
    }

    // Criterion 8
    func testProgressGoesFrom0To1AndNeverBackAndTheExportTimeIsPrinted() async throws {
        let made = try await Self.threeClips.value
        print("m1-5-engine: the export of three-clips took \(made.seconds) seconds, expected 40, limit 120")
        XCTAssertLessThanOrEqual(made.seconds, 120)

        XCTAssertEqual(made.progress.first, 0)
        XCTAssertEqual(made.progress.last, 1)
        XCTAssertTrue(made.progress.allSatisfy { $0 >= 0 && $0 <= 1 }, "\(made.progress)")
        XCTAssertTrue(zip(made.progress, made.progress.dropFirst()).allSatisfy { $0 <= $1 }, "\(made.progress)")
    }

    // Criterion 9
    func testAnEmptyPlanThrowsNothingToExportAndLeavesNoFile() async throws {
        let folder = try emptyFolder()
        let output = folder.appendingPathComponent("out.mp4")
        do {
            try await export(
                plan: RenderPlan(segments: [], duration: .zero), media: [:], mediaFolder: folder, to: output) { _ in }
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .nothingToExport)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    // Criterion 9
    func testAMissingSourceThrowsSourceMissingWithTheIdAndLeavesNoFile() async throws {
        let mediaFolder = try emptyFolder()
        let folder = try emptyFolder()
        let output = folder.appendingPathComponent("out.mp4")
        let project = Seed.threeClips.project
        do {
            try await export(
                plan: try renderPlan(for: project), media: project.media, mediaFolder: mediaFolder, to: output) { _ in }
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .sourceMissing(MediaID("blue")))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    // Criterion 9
    func testAnOutputPlaceThatCannotBeWrittenThrowsCannotWriteAndLeavesNoFile() async throws {
        for clip in Seed.threeClips.testClips {
            _ = try await writeTestClip(clip, to: Self.folder)
        }
        let folder = try emptyFolder()
        let output = folder.appendingPathComponent("missing").appendingPathComponent("out.mp4")
        let project = Seed.threeClips.project
        do {
            try await export(
                plan: try renderPlan(for: project), media: project.media, mediaFolder: Self.folder, to: output) { _ in }
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotWrite)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    /// The plan of one test clip alone, whole.
    private func planOfOne(_ clip: TestClip) throws -> RenderPlan {
        var project = Project()
        project.media[clip.info.id] = clip.info
        project.clips.append(Clip(id: ClipID(1), media: clip.info.id, sourceStart: .zero, duration: clip.duration))
        return try renderPlan(for: project)
    }

    private func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("m1-5-engine-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The peak of the first sound track from zero up to a time, from 0 to 1 of full scale.
    /// https://developer.apple.com/documentation/avfoundation/avassetreader/timerange
    private func soundPeak(of file: URL, upTo end: Time) async throws -> Double {
        let asset = AVURLAsset(url: file)
        let soundTracks = try await asset.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(soundTracks.first)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(value: end.ticks, timescale: 600))
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        guard reader.startReading() else { throw try XCTUnwrap(reader.error) }
        var peak = 0
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            guard length >= 2 else { continue }
            var samples = [Int16](repeating: 0, count: length / 2)
            let status = samples.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
            }
            XCTAssertEqual(status, kCMBlockBufferNoErr)
            for sample in samples {
                peak = max(peak, abs(Int(sample)))
            }
        }
        guard reader.status == .completed else { throw try XCTUnwrap(reader.error) }
        return Double(peak) / 32768
    }

    /// The profile number in the H.264 configuration of the picture track.
    /// https://developer.apple.com/documentation/coremedia/kcmformatdescriptionextension_sampledescriptionextensionatoms
    private func h264Profile(of file: URL) async throws -> Int {
        let asset = AVURLAsset(url: file)
        let pictureTracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(pictureTracks.first)
        let descriptions = try await track.load(.formatDescriptions)
        let description = try XCTUnwrap(descriptions.first)
        let atoms = CMFormatDescriptionGetExtension(
            description, extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms) as? [String: Any]
        let configuration = try XCTUnwrap(atoms?["avcC"] as? Data)
        let bytes = [UInt8](configuration)
        XCTAssertGreaterThan(bytes.count, 1)
        return Int(bytes[1])
    }
}

/// Collects the progress values of one export, which may come from any thread.
final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var collected: [Double] = []

    func add(_ value: Double) {
        lock.lock()
        collected.append(value)
        lock.unlock()
    }

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return collected
    }
}

/// A colour matches within 24 of 255 per channel.
func assertNear(_ colour: RGB, _ wanted: RGB, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(Int(colour.r) - Int(wanted.r)), 24, what + " red", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.g) - Int(wanted.g)), 24, what + " green", file: file, line: line)
    XCTAssertLessThanOrEqual(abs(Int(colour.b) - Int(wanted.b)), 24, what + " blue", file: file, line: line)
}
#endif
