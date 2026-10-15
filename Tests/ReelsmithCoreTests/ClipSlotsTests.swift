import Foundation
import XCTest

/// Holds the four groups for the words of clips at the end of each word file. What stands inside a group is not read.
final class ClipSlotsTests: XCTestCase {
    func testEachWordFileEndsWithTheFourSlotsOfClipsInTheirOrder() throws {
        var wanted: [String] = []
        for topic in ["add-clips", "clip-panel", "music-row", "clip-path", "framing", "guide", "fold-frames"] {
            wanted += ["/* slot: " + topic + " */", "/* end slot: " + topic + " */"]
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        for language in ["en", "ar", "sv"] {
            let file = repository.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
            let lines = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline)
            let marks = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.contains("slot: ") }

            XCTAssertEqual(Array(marks.suffix(wanted.count)), wanted, language)
        }
    }
}
