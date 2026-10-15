#if canImport(AVFoundation)
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The volume of each clip, read by pitch from exported files of `two-clips-wide` and `music-wide`. The clips sound
/// at 440 Hz with a peak of 0.5. Blue fills 0 to 1800 ticks and red 1800 to 4200, and each is read over a window
/// that leaves out the join: blue from 0.5 to 2.5 seconds, red from 3.5 to 6.5. A volume is a plain factor on the
/// level, so red at 0.5 reads half of what it reads at 1.
final class ClipMixTests: XCTestCase {
    /// The export of `two-clips-wide` with red at 0.5, made once for the tests that read it.
    static let redAtHalf = Task<URL, Error> {
        var project = Seed.twoClipsWide.project
        project.clips[1].volume = 0.5
        return try await ClipMixTests.exported(project, name: "red-half.out")
    }

    static func exported(_ project: Project, name: String) async throws -> URL {
        try await ExportTests.exported(try renderPlan(for: project), clips: [.blue, .red], name: name).file
    }

    func testRedAtHalfReads440AtHalfTheLevelOfBlue() async throws {
        let file = try await Self.redAtHalf.value
        let blue = try await toneLevel(of: file, hertz: 440, from: blueStart, to: blueEnd)
        let red = try await toneLevel(of: file, hertz: 440, from: redStart, to: redEnd)
        print("clip mix: red at 0.5 reads \(red / blue) of blue")
        assertLevel(blue, near: 0.5, "blue at 1")
        assertLevel(red, near: 0.5 * blue, "red at 0.5")
    }

    func testTheClipsAtHalfAndRedAtHalfReadBlueAtHalfAndRedAtAQuarterOfBlueAtOne() async throws {
        let reference = try await toneLevel(of: try await Self.redAtHalf.value, hertz: 440, from: blueStart, to: blueEnd)
        var project = Seed.twoClipsWide.project
        project.clipVolume = 0.5
        project.clips[1].volume = 0.5
        let file = try await Self.exported(project, name: "clips-half-red-half.out")
        let blue = try await toneLevel(of: file, hertz: 440, from: blueStart, to: blueEnd)
        let red = try await toneLevel(of: file, hertz: 440, from: redStart, to: redEnd)
        print("clip mix: the clips at 0.5 read blue at \(blue / reference) and red at \(red / reference) of blue at 1")
        assertLevel(blue, near: 0.5 * reference, "blue with the clips at 0.5")
        assertLevel(red, near: 0.25 * reference, "red at 0.5 with the clips at 0.5")
    }

    func testTheClipsMutedWithRedAtHalfAreSilentInBothRanges() async throws {
        var project = Seed.twoClipsWide.project
        project.clipsMuted = true
        project.clips[1].volume = 0.5
        let file = try await Self.exported(project, name: "clips-muted-red-half.out")
        let blue = try await toneLevel(of: file, hertz: 440, from: blueStart, to: blueEnd)
        let red = try await toneLevel(of: file, hertz: 440, from: redStart, to: redEnd)
        XCTAssertLessThan(blue, 0.02, "blue muted")
        XCTAssertLessThan(red, 0.02, "red muted")
    }

    func testMusicWideWithRedAtHalfReadsTheMusicAsBeforeAndRedAtHalfTheLevelOfBlue() async throws {
        var project = Seed.musicWide.project
        project.clips[1].volume = 0.5
        let file = try await SoundExportTests.exported(project, tones: [.long], name: "music-red-half.out")
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        let blue = try await toneLevel(of: file, hertz: 440, from: blueStart, to: blueEnd)
        let red = try await toneLevel(of: file, hertz: 440, from: redStart, to: redEnd)
        assertLevel(music, near: 0.25, "880 Hz")
        assertLevel(blue, near: 0.5, "blue at 1")
        assertLevel(red, near: 0.5 * blue, "red at 0.5")
    }
}

private let blueStart = Time(ticks: 300)
private let blueEnd = Time(ticks: 1500)
private let redStart = Time(ticks: 2100)
private let redEnd = Time(ticks: 3900)

/// A level matches within 15 percent of its expected value.
private func assertLevel(
    _ level: Double, near expected: Double, _ what: String, file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertLessThanOrEqual(
        abs(level - expected), 0.15 * expected, what + " reads \(level), expected \(expected)", file: file, line: line)
}
#endif
