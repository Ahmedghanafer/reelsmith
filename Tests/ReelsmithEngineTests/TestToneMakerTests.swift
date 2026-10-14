#if canImport(AVFoundation)
import AVFoundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

final class TestToneMakerTests: XCTestCase {
    /// One folder for the whole run. A tone is written by the first test that asks for it and kept for the rest.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("tones-" + UUID().uuidString)

    func testEachToneIsAQuickTimeFileWithOneMonoSoundTrackOfSixteenBitsAndItsExactLength() async throws {
        let lengths = ["long-tone": Int64(6000), "short-tone": Int64(1200)]
        for tone in [TestTone.long, TestTone.short] {
            let file = try await writeTestTone(tone, to: Self.folder)
            XCTAssertEqual(file, Self.folder.appendingPathComponent(tone.name + ".mov"), tone.name)
            XCTAssertEqual(try fileType(of: file), "qt  ", tone.name)

            let all = try await tracks(of: file)
            XCTAssertEqual(all.count, 1, tone.name + " tracks")
            let sound = try XCTUnwrap(all.first)
            XCTAssertEqual(sound.kind, "soun", tone.name)
            XCTAssertEqual(sound.coding, "lpcm", tone.name)
            XCTAssertEqual(sound.bitsPerSample, 16, tone.name)
            XCTAssertEqual(sound.sampleRate, 44100, tone.name)
            XCTAssertEqual(sound.channels, 1, tone.name)
            let ticks = try XCTUnwrap(lengths[tone.name])
            XCTAssertEqual(sound.duration, CMTime(value: ticks, timescale: 600), tone.name)
        }
    }

    func testTheLongToneSounds880HertzInItsFirstHalfAnd1320InItsSecond() async throws {
        let file = try await writeTestTone(TestTone.long, to: Self.folder)

        let first = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        let notYet = try await toneLevel(of: file, hertz: 1320, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(first, near: 0.25, "880 Hz between 600 and 1200 ticks")
        XCTAssertLessThan(notYet, 0.02, "1320 Hz between 600 and 1200 ticks")

        let second = try await toneLevel(of: file, hertz: 1320, from: Time(ticks: 3600), to: Time(ticks: 4200))
        let gone = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 3600), to: Time(ticks: 4200))
        assertLevel(second, near: 0.25, "1320 Hz between 3600 and 4200 ticks")
        XCTAssertLessThan(gone, 0.02, "880 Hz between 3600 and 4200 ticks")
    }

    func testTheShortToneSounds660HertzInBothHalves() async throws {
        let file = try await writeTestTone(TestTone.short, to: Self.folder)

        let first = try await toneLevel(of: file, hertz: 660, from: .zero, to: Time(ticks: 600))
        let second = try await toneLevel(of: file, hertz: 660, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(first, near: 0.25, "660 Hz between 0 and 600 ticks")
        assertLevel(second, near: 0.25, "660 Hz between 600 and 1200 ticks")
    }

    func testMakesTheMissingFolderWritesUnderATemporaryNameThenRenames() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tones-" + UUID().uuidString)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        let watcher = Task.detached { () -> Bool in
            var sawOnlyAnotherName = false
            while !Task.isCancelled {
                let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
                if !names.isEmpty && !names.contains("long-tone.mov") {
                    sawOnlyAnotherName = true
                }
                // No pause: an uncompressed tone is written in a few milliseconds.
                await Task.yield()
            }
            return sawOnlyAnotherName
        }
        _ = try await writeTestTone(TestTone.long, to: folder)
        watcher.cancel()
        let sawOnlyAnotherName = await watcher.value

        XCTAssertTrue(sawOnlyAnotherName)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["long-tone.mov"])
    }

    func testASecondCallKeepsTheFileThatIsAlreadyThere() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tones-" + UUID().uuidString)
        let file = try await writeTestTone(TestTone.short, to: folder)
        let before = try FileManager.default.attributesOfItem(atPath: file.path)

        let again = try await writeTestTone(TestTone.short, to: folder)
        let after = try FileManager.default.attributesOfItem(atPath: again.path)

        XCTAssertEqual(again, file)
        XCTAssertEqual(after[.size] as? Int, before[.size] as? Int)
        XCTAssertNotNil(before[.modificationDate] as? Date)
        XCTAssertEqual(after[.modificationDate] as? Date, before[.modificationDate] as? Date)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["short-tone.mov"])
    }
}

/// A level matches within 15 percent of its expected value.
private func assertLevel(
    _ level: Double, near expected: Double, _ what: String, file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertLessThanOrEqual(
        abs(level - expected), 0.15 * expected, what + " reads \(level), expected \(expected)", file: file, line: line)
}
#endif
