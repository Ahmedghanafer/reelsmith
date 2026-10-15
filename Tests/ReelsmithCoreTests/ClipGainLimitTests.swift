import ReelsmithCore
import XCTest

/// The volume of a clip goes from 0 to 2, on `two-clips-wide`.
final class ClipGainLimitTests: XCTestCase {
    private let red = ClipID(2)
    private let wide = EditorState(project: Seed.twoClipsWide.project)

    private func volumeOfRed(after volume: Double) -> Double? {
        reduce(wide, .sound(.setVolumeOfClip(red, volume))).project.clips.first { $0.id == red }?.volume
    }

    func testSetVolumeOfClipHoldsTwoAndAHalfAtTwoAndMinusOneAtZeroAndKeepsOneAndAHalf() {
        XCTAssertEqual(volumeOfRed(after: 2.5), 2)
        XCTAssertEqual(volumeOfRed(after: -1), 0)
        XCTAssertEqual(volumeOfRed(after: 1.5), 1.5)
    }

    func testClipInfoOfAClipAtTwoEndsWithTwoHundredV() {
        let state = reduce(wide, .sound(.setVolumeOfClip(red, 2)))
        XCTAssertEqual(state.project.clipInfo(red), "red 0+2400 200 v")
    }
}
