import Foundation
import XCTest

/// Holds the five groups of the drafts and of undo at the end of each word file, the last two empty.
final class DraftSlotsTests: XCTestCase {
    func testEachWordFileEndsWithTheFiveSlotsInTheirOrderTheLastTwoEmpty() throws {
        var wanted: [String] = []
        for topic in ["undo", "draft-saving", "project-list", "draft-delete", "draft-path"] {
            wanted += ["/* slot: " + topic + " */", "/* end slot: " + topic + " */"]
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        for language in ["en", "ar", "sv"] {
            let file = repository.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
            let lines = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline)
            let filled = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

            // The last ten marks are the five groups in their order. The groups undo, draft-saving and project-list
            // hold their words, and the last four lines that are not blank are the marks alone, so each group after
            // them is empty.
            let marks = filled.filter { $0.hasPrefix("/* slot: ") || $0.hasPrefix("/* end slot: ") }
            XCTAssertEqual(Array(marks.suffix(wanted.count)), wanted, language)
            XCTAssertEqual(Array(filled.suffix(4)), Array(wanted.suffix(4)), language)
        }
    }
}
