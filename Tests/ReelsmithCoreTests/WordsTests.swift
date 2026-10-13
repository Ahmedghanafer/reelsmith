import ReelsmithCore
import XCTest

final class WordsTests: XCTestCase {
    func testWordsHoldAKeyAndItsArguments() {
        XCTAssertEqual(Words("export.saved").key, "export.saved")
        XCTAssertEqual(Words("export.saved").arguments, [])
        XCTAssertEqual(Words("clip.count", ["2"]).arguments, ["2"])
    }

    func testWordsAreEqualExactlyWhenKeyAndArgumentsAre() {
        XCTAssertEqual(Words("clip.count", ["2"]), Words("clip.count", ["2"]))
        XCTAssertNotEqual(Words("clip.count", ["2"]), Words("clip.length", ["2"]))
        XCTAssertNotEqual(Words("clip.count", ["2"]), Words("clip.count", ["3"]))
    }

    func testClockTextAndTimeLabelArePlainText() {
        let clock: String = Time.zero.clockText
        let label: String = EditorState(project: Seed.empty.project).timeLabel

        XCTAssertEqual(clock, "00:00")
        XCTAssertEqual(label, "00:00 / 00:00")
    }
}
