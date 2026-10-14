import Foundation
import XCTest

/// The words of deleting a draft stand in the group `draft-delete` of the three word files, and nothing else
/// stands there: the button of the swipe and of the alert, the question of the alert and its cancel.
final class DraftDeleteWordsTests: XCTestCase {
    private let keys = ["drafts.delete", "drafts.deleteQuestion", "drafts.deleteCancel"]

    func testTheGroupDraftDeleteHoldsItsThreeKeysInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, keys, language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheTextsOfTheGroupDraftDelete() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Delete", "Delete this project?", "Cancel"])
        XCTAssertEqual(try group(of: "ar").map { $0.text }, ["حذف", "حذف هذا المشروع؟", "إلغاء"])
        XCTAssertEqual(try group(of: "sv").map { $0.text }, ["Radera", "Radera det här projektet?", "Avbryt"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: draft-delete */")
        guard after.count == 2 else {
            XCTFail(language + ": the group draft-delete is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: draft-delete */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
