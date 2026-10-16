import Foundation
import XCTest

/// The label of the music bar of the strip stands in the group `music-row` of the three word files, and nothing
/// else stands there. The title of the music goes in at the same placeholder in every language.
final class MusicRowWordsTests: XCTestCase {
    func testTheGroupMusicRowHoldsItsOneKeyInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            XCTAssertEqual(try group(of: language).map { $0.key }, ["musicRow.bar"], language)
        }
    }

    func testTheTextOfTheGroupMusicRowInEachLanguage() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Music %1$@"])
        XCTAssertEqual(try group(of: "ar").map { $0.text }, ["الموسيقى %1$@"])
        XCTAssertEqual(try group(of: "sv").map { $0.text }, ["Musik %1$@"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/assets/words/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: music-row */")
        guard after.count == 2 else {
            XCTFail(language + ": the group music-row is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: music-row */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
