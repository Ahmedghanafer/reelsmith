import Foundation
import XCTest

/// The words of the button that adds clips stand in the group `add-clips` of the three word files, and nothing else
/// stands there. The Arabic word is the noun of the act, not an imperative.
final class AddClipsWordsTests: XCTestCase {
    func testTheGroupAddClipsHoldsItsOneKeyInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            XCTAssertEqual(try group(of: language).map { $0.key }, ["tools.add"], language)
        }
    }

    func testTheTextOfTheGroupAddClipsInEachLanguage() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Add"])
        XCTAssertEqual(try group(of: "ar").map { $0.text }, ["إضافة"])
        XCTAssertEqual(try group(of: "sv").map { $0.text }, ["Lägg till"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/assets/words/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: add-clips */")
        guard after.count == 2 else {
            XCTFail(language + ": the group add-clips is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: add-clips */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
