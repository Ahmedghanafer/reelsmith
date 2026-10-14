import Foundation
import XCTest

/// Holds the two groups for the words of export at the end of each word file, after the last group of sound.
/// What stands inside a group is not read.
final class ExportSlotsTests: XCTestCase {
    func testEachWordFileEndsWithTheTwoSlotsOfExportAfterSoundPath() throws {
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

            XCTAssertEqual(Array(marks.suffix(wanted.count)), wanted, language)
        }
    }
}
