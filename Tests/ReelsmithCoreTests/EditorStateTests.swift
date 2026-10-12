import ReelsmithCore
import XCTest

final class EditorStateTests: XCTestCase {
    func testANewStateHasNoSelectionThePlayheadAtZeroAndIsNotPlaying() {
        let state = EditorState(project: Seed.twoClips.project)

        XCTAssertEqual(state.project, Seed.twoClips.project)
        XCTAssertNil(state.selection)
        XCTAssertEqual(state.playhead, Time.zero)
        XCTAssertFalse(state.isPlaying)
    }

    func testTimeLabelOfTwoClipsReadsPlayheadAndLength() {
        XCTAssertEqual(EditorState(project: Seed.twoClips.project).timeLabel, "00:00 / 00:07")
    }

    func testCanPlayAndCanExportOnlyWhenTheProjectHasClips() {
        let empty = EditorState(project: Seed.empty.project)
        XCTAssertFalse(empty.canPlay)
        XCTAssertFalse(empty.canExport)

        for seed in [Seed.twoClips, Seed.threeClips] {
            let state = EditorState(project: seed.project)
            XCTAssertTrue(state.canPlay, seed.rawValue)
            XCTAssertTrue(state.canExport, seed.rawValue)
        }
    }
}
