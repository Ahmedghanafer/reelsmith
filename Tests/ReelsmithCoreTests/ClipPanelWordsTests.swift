import Foundation
import XCTest

/// The words of the clip panel stand in the group `clip-panel` of the three word files, and nothing else stands
/// there. The Arabic words are nouns of the act, not imperatives.
final class ClipPanelWordsTests: XCTestCase {
    func testTheGroupClipPanelHoldsItsThreeKeysInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            XCTAssertEqual(
                try group(of: language).map { $0.key }, ["clip.cutBefore", "clip.cutAfter", "clip.volume"], language)
        }
    }

    func testTheTextOfTheGroupClipPanelInEachLanguage() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Delete before", "Delete after", "Volume"])
        XCTAssertEqual(try group(of: "ar").map { $0.text }, ["حذف ما قبل", "حذف ما بعد", "مستوى الصوت"])
        XCTAssertEqual(try group(of: "sv").map { $0.text }, ["Radera före", "Radera efter", "Volym"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: clip-panel */")
        guard after.count == 2 else {
            XCTFail(language + ": the group clip-panel is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: clip-panel */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
