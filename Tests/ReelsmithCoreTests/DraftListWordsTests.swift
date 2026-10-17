import Foundation
import XCTest

/// The words of the project list stand in the group `project-list` of the three word files, and nothing else
/// stands there. The row label carries the date and the length in the same two placeholders in every language.
final class DraftListWordsTests: XCTestCase {
    private let keys = ["editor.projects", "drafts.title", "drafts.row", "drafts.unreadable"]

    func testTheGroupProjectListHoldsItsFourKeysInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, keys, language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextsOfTheGroupProjectList() throws {
        XCTAssertEqual(
            try group(of: "en").map { $0.text },
            ["Projects", "Projects", "Project of %1$@, %2$@ long", "This project cannot be opened"])
    }

    func testTheRowLabelHasTheTwoPlaceholdersInEveryLanguage() throws {
        for language in ["en", "ar", "sv"] {
            let row = try group(of: language).first { $0.key == "drafts.row" }?.text ?? ""
            XCTAssertEqual(row.components(separatedBy: "%1$@").count, 2, language)
            XCTAssertEqual(row.components(separatedBy: "%2$@").count, 2, language)
            for (index, line) in try group(of: language).enumerated() where index != 2 {
                XCTAssertFalse(line.text.contains("%"), language + " " + line.key)
            }
        }
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/assets/words/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: project-list */")
        guard after.count == 2 else {
            XCTFail(language + ": the group project-list is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: project-list */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
