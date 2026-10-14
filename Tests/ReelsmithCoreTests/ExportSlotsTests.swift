import Foundation
import XCTest

/// Holds the two groups for the words of export after the last group of sound in each word file.
/// What stands inside a group is not read.
final class ExportSlotsTests: XCTestCase {
    func testTheTwoSlotsOfExportFollowTheEndOfSoundPathInTheirOrder() throws {
        let wanted = [
            "/* end slot: sound-path */",
            "/* slot: export-settings */", "/* end slot: export-settings */",
            "/* slot: export-path */", "/* end slot: export-path */",
        ]
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        for language in ["en", "ar", "sv"] {
            let file = repository.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
            let lines = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline)
            let marks = lines.map(String.init).filter { $0.contains("slot: ") }
            let start = try XCTUnwrap(marks.firstIndex(of: wanted[0]), language)

            XCTAssertEqual(Array(marks[start...].prefix(wanted.count)), wanted, language)
        }
    }
}
