#if canImport(AVFoundation)
import AVFoundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

final class TestClipMakerTests: XCTestCase {
    /// One folder for the whole run. A clip is written by the first test that asks for it and kept for the rest.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("m1-2a-engine-target-" + UUID().uuidString)

    private let frames = ["blue": 90, "red": 120, "green": 60, "turned": 60, "fast": 120]

    func testEveryClipHasTheSizeTheFramesTheLengthAndTheColoursOfTheTable() async throws {
        for clip in TestClip.all {
            let file = try await writeTestClip(clip, to: Self.folder)
            XCTAssertEqual(file, Self.folder.appendingPathComponent(clip.name + ".mov"), clip.name)
            XCTAssertEqual(try fileType(of: file), "qt  ", clip.name)

            let size = try await storedSize(of: file)
            XCTAssertEqual(size.width, clip.storedWidth, clip.name)
            XCTAssertEqual(size.height, clip.storedHeight, clip.name)

            let picture = try await tracks(of: file).filter { $0.kind == "vide" }
            XCTAssertEqual(picture.count, 1, clip.name)
            XCTAssertEqual(picture.first?.coding, "avc1", clip.name)
            XCTAssertEqual(picture.first?.duration, CMTime(value: clip.duration.ticks, timescale: 600), clip.name)

            let count = try await frameCount(of: file)
            XCTAssertEqual(count, frames[clip.name], clip.name)

            let half = Time(ticks: clip.duration.ticks / 2)
            let left = try await pixel(of: file, at: half, x: clip.storedWidth / 4, y: clip.storedHeight / 2)
            let right = try await pixel(of: file, at: half, x: clip.storedWidth * 3 / 4, y: clip.storedHeight / 2)
            assertColour(left, isNear: clip.left, clip.name + " left")
            assertColour(right, isNear: clip.right, clip.name + " right")
        }
    }

    func testWritesUnderATemporaryNameThenRenames() async throws {
        let folder = try emptyFolder()
        let watcher = Task.detached { () -> Bool in
            var sawOnlyAnotherName = false
            while !Task.isCancelled {
                let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
                if !names.isEmpty && !names.contains("green.mov") {
                    sawOnlyAnotherName = true
                }
                try? await Task.sleep(nanoseconds: 2_000_000)
            }
            return sawOnlyAnotherName
        }
        _ = try await writeTestClip(TestClip.green, to: folder)
        watcher.cancel()
        let sawOnlyAnotherName = await watcher.value

        XCTAssertTrue(sawOnlyAnotherName)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["green.mov"])
    }

    func testAFileThatIsAlreadyThereIsKept() async throws {
        let folder = try emptyFolder()
        let there = Data("kept".utf8)
        try there.write(to: folder.appendingPathComponent("green.mov"))

        let file = try await writeTestClip(TestClip.green, to: folder)

        XCTAssertEqual(try Data(contentsOf: file), there)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["green.mov"])
    }

    func testBlueAndRedHaveOneMonoSoundTrackAndTheOthersNone() async throws {
        for clip in TestClip.all {
            let file = try await writeTestClip(clip, to: Self.folder)
            let sound = try await tracks(of: file).filter { $0.kind == "soun" }
            guard clip.name == "blue" || clip.name == "red" else {
                XCTAssertEqual(sound.count, 0, clip.name)
                continue
            }
            XCTAssertEqual(sound.count, 1, clip.name)
            XCTAssertEqual(sound.first?.coding, "lpcm", clip.name)
            XCTAssertEqual(sound.first?.bitsPerSample, 16, clip.name)
            XCTAssertEqual(sound.first?.sampleRate, 44100, clip.name)
            XCTAssertEqual(sound.first?.channels, 1, clip.name)
            XCTAssertEqual(sound.first?.duration, CMTime(value: clip.duration.ticks, timescale: 600), clip.name)

            let peak = try await soundPeak(of: file)
            XCTAssertGreaterThanOrEqual(peak, 0.4, clip.name)
            XCTAssertLessThanOrEqual(peak, 0.6, clip.name)
        }
    }

    func testEveryClipReportsThe709ColourProperties() async throws {
        for clip in TestClip.all {
            let file = try await writeTestClip(clip, to: Self.folder)
            let colour = try await colourProperties(of: file)
            XCTAssertEqual(colour.primaries, kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String, clip.name)
            XCTAssertEqual(colour.transfer, kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String, clip.name)
            XCTAssertEqual(colour.matrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String, clip.name)
        }
    }

    func testTheStoredTransformOfTurnedIsOneQuarterTurn() async throws {
        let file = try await writeTestClip(TestClip.turned, to: Self.folder)
        let transform = try await storedTransform(of: file)
        XCTAssertEqual(transform, [0, 1, -1, 0, 1080, 0])
    }

    func testLeavesBlueAndRedInTheClipFolder() async throws {
        guard let path = ProcessInfo.processInfo.environment["REELSMITH_CLIP_DIR"] else {
            throw XCTSkip("REELSMITH_CLIP_DIR is not set")
        }
        let folder = URL(fileURLWithPath: path)
        for clip in [TestClip.blue, TestClip.red] {
            _ = try await writeTestClip(clip, to: folder)
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(clip.name + ".mov").path))
        }
    }

    private func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("m1-2a-engine-target-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func assertColour(_ colour: RGB, isNear wanted: RGB, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(abs(Int(colour.r) - Int(wanted.r)), 24, what + " red", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(Int(colour.g) - Int(wanted.g)), 24, what + " green", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(Int(colour.b) - Int(wanted.b)), 24, what + " blue", file: file, line: line)
    }
}
#endif
