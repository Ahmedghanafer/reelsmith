import Foundation
import XCTest

/// The words of undo and redo stand in the group `undo` of the three word files, and nothing else stands there.
final class UndoWordsTests: XCTestCase {
    func testTheGroupUndoHoldsItsTwoKeysInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, ["editor.undo", "editor.redo"], language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextsOfTheGroupUndo() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Undo", "Redo"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: undo */")
        guard after.count == 2 else {
            XCTFail(language + ": the group undo is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: undo */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
