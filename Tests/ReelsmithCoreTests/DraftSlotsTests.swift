import Foundation
import XCTest

/// Holds the four groups of the drafts and of undo at the end of each word file, the three of the drafts empty.
final class DraftSlotsTests: XCTestCase {
    func testEachWordFileEndsWithTheFourSlotsInTheirOrderTheLastThreeEmpty() throws {
        var wanted: [String] = []
        for topic in ["undo", "project-list", "draft-delete", "draft-path"] {
            wanted += ["/* slot: " + topic + " */", "/* end slot: " + topic + " */"]
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        for language in ["en", "ar", "sv"] {
            let file = repository.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
            let lines = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline)
            let filled = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

            // The last eight marks are the four groups in their order. The group undo holds its words, and the
            // last six lines that are not blank are the marks alone, so each group after it is empty.
            let marks = filled.filter { $0.hasPrefix("/* slot: ") || $0.hasPrefix("/* end slot: ") }
            XCTAssertEqual(Array(marks.suffix(wanted.count)), wanted, language)
            XCTAssertEqual(Array(filled.suffix(6)), Array(wanted.suffix(6)), language)
        }
    }
}
