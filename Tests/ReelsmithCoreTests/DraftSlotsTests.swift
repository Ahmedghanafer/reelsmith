import Foundation
import XCTest

/// Holds the five groups of the drafts and of undo after the last group of export in each word file.
/// What stands inside a group is not read.
final class DraftSlotsTests: XCTestCase {
    func testTheFiveSlotsOfDraftsFollowTheEndOfExportPathInTheirOrder() throws {
        var wanted = ["/* end slot: export-path */"]
        for topic in ["undo", "draft-saving", "project-list", "draft-delete", "draft-path"] {
            wanted += ["/* slot: " + topic + " */", "/* end slot: " + topic + " */"]
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        for language in ["en", "ar", "sv"] {
            let file = repository.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
            let lines = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline)
            let marks = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.contains("slot: ") }
            let start = try XCTUnwrap(marks.firstIndex(of: wanted[0]), language)

            XCTAssertEqual(Array(marks[start...].prefix(wanted.count)), wanted, language)
        }
    }
}
