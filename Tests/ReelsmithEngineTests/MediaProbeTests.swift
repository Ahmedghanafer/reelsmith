#if canImport(AVFoundation)
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import XCTest

// The mapping from a stored transform to quarter turns and the rounding of a length to ticks are internal
// to the Engine.
@testable import ReelsmithEngine

final class MediaProbeTests: XCTestCase {
    /// One folder for the whole run. A clip is written by the first test that asks for it and kept for the rest.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("m1-6a-media-facts-" + UUID().uuidString)

    func testTheFileOfEveryTestClipReadsAsTheInfoOfThatClip() async throws {
        for clip in TestClip.all {
            _ = try await writeTestClip(clip, to: Self.folder)
            let info = try await readMediaInfo(id: MediaID(clip.name), fileName: clip.name + ".mov", in: Self.folder)
            XCTAssertEqual(info, clip.info, clip.name)
        }
    }

    func testTurnedReadsAsOneQuarterTurnWithAStoredSizeOf1920By1080() async throws {
        _ = try await writeTestClip(TestClip.turned, to: Self.folder)
        let info = try await readMediaInfo(id: MediaID("turned"), fileName: "turned.mov", in: Self.folder)

        XCTAssertEqual(info.quarterTurns, 1)
        XCTAssertEqual(info.width, 1920)
        XCTAssertEqual(info.height, 1080)
        XCTAssertEqual(info.duration, Time(ticks: 1200))
        XCTAssertFalse(info.hasSound)
    }

    func testTheIdGivenIsTheIdOfTheInfo() async throws {
        _ = try await writeTestClip(TestClip.blue, to: Self.folder)
        let info = try await readMediaInfo(id: MediaID("picked"), fileName: "blue.mov", in: Self.folder)

        XCTAssertEqual(info.id, MediaID("picked"))
        XCTAssertEqual(info.fileName, "blue.mov")
        XCTAssertEqual(info.width, 1920)
        XCTAssertEqual(info.height, 1080)
        XCTAssertEqual(info.duration, Time(ticks: 1800))
        XCTAssertEqual(info.quarterTurns, 0)
        XCTAssertTrue(info.hasSound)
    }

    func testTheFourStoredTransformsMapToTheirQuarterTurns() {
        // The six numbers a, b, c, d, tx, ty of a picture stored 1920 by 1080.
        XCTAssertEqual(quarterTurns(of: CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)), 0)
        XCTAssertEqual(quarterTurns(of: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)), 1)
        XCTAssertEqual(quarterTurns(of: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 1920, ty: 1080)), 2)
        XCTAssertEqual(quarterTurns(of: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 1920)), 3)
    }

    func testALengthIsRoundedDownToATick() {
        XCTAssertEqual(wholeTicks(of: CMTime(value: 2999, timescale: 3000)), 599)
        XCTAssertEqual(wholeTicks(of: CMTime(value: 1001, timescale: 30000)), 20)
        XCTAssertEqual(wholeTicks(of: CMTime(value: 1800, timescale: 600)), 1800)
    }

    func testAFileThatIsNotAVideoThrowsCannotRead() async throws {
        let folder = try emptyFolder()
        try Data("not a video".utf8).write(to: folder.appendingPathComponent("note.mov"))
        do {
            _ = try await readMediaInfo(id: MediaID("note"), fileName: "note.mov", in: folder)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
    }

    func testAFileNameThatIsNotInTheFolderThrowsSourceMissingWithTheId() async throws {
        let folder = try emptyFolder()
        do {
            _ = try await readMediaInfo(id: MediaID("gone"), fileName: "gone.mov", in: folder)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .sourceMissing(MediaID("gone")))
        }
    }

    private func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("m1-6a-media-facts-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
#endif
