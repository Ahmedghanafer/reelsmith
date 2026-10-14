import Foundation
import XCTest

/// The words of the part more of a text, its alignment, its line spacing and its three marks, stand in the
/// group `text-more` of the three word files, and nothing else stands there.
final class TextMoreWordsTests: XCTestCase {
    func testTheGroupTextMoreHoldsItsSevenKeysInAllThreeWordFiles() throws {
        let expected = [
            "text.align.left", "text.align.centre", "text.align.right", "text.spacing", "text.outline", "text.shadow",
            "text.box",
        ]
        for language in ["en", "ar", "sv"] {
            XCTAssertEqual(try group(of: language).map { $0.key }, expected, language)
        }
    }

    func testTheEnglishTextsOfTheGroupTextMore() throws {
        XCTAssertEqual(
            try group(of: "en").map { $0.text },
            ["Left", "Centre", "Right", "Line spacing", "Outline", "Shadow", "Box"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: text-more */")
        guard after.count == 2 else {
            XCTFail(language + ": the group text-more is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: text-more */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
