import Foundation
import XCTest

/// Holds the four empty groups of the drafts and of undo at the end of each word file.
final class DraftSlotsTests: XCTestCase {
    func testEachWordFileEndsWithTheFourEmptySlotsInTheirOrder() throws {
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

            // The last eight lines that are not blank are the marks alone, so each group is empty.
            XCTAssertEqual(Array(filled.suffix(wanted.count)), wanted, language)
        }
    }
}
