import ReelsmithCore
import XCTest

/// The rows of the strip, unfolded as they were and folded to thin blocks.
final class StripRowsTests: XCTestCase {
    func testUnfoldedTheRowsAreTheRowsOfToday() {
        for textSelected in [false, true] {
            let rows = StripRows.of(folded: false, textSelected: textSelected)
            XCTAssertEqual(rows.clipY, 8)
            XCTAssertEqual(rows.clipHeight, 56)
            XCTAssertEqual(rows.textY, 72)
            XCTAssertEqual(rows.musicY, 100)
            XCTAssertEqual(rows.rowHeight, 24)
        }
        XCTAssertEqual(StripRows.of(folded: false, textSelected: false).height, 128)
        XCTAssertEqual(StripRows.of(folded: false, textSelected: true).height, 104)
    }

    func testFoldedTheBlocksAre24HighAndTheRowsMoveUp32() {
        for textSelected in [false, true] {
            let rows = StripRows.of(folded: true, textSelected: textSelected)
            XCTAssertEqual(rows.clipY, 8)
            XCTAssertEqual(rows.clipHeight, 24)
            XCTAssertEqual(rows.textY, 40)
            XCTAssertEqual(rows.musicY, 68)
            XCTAssertEqual(rows.rowHeight, 24)
        }
        XCTAssertEqual(StripRows.of(folded: true, textSelected: false).height, 96)
        XCTAssertEqual(StripRows.of(folded: true, textSelected: true).height, 72)
    }
}
