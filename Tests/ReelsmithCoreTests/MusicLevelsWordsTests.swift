import Foundation
import XCTest

/// The words of the part levels of the sound panel, its four sliders and the line with no music, stand in the
/// group `music-levels` of the three word files, and nothing else stands there.
final class MusicLevelsWordsTests: XCTestCase {
    func testTheGroupMusicLevelsHoldsItsFiveKeysInAllThreeWordFiles() throws {
        let expected = ["music.volume", "music.start", "music.fadeIn", "music.fadeOut", "music.none"]
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, expected, language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextsOfTheGroupMusicLevels() throws {
        XCTAssertEqual(
            try group(of: "en").map { $0.text }, ["Music volume", "Starts at", "Fade in", "Fade out", "No music yet"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/assets/words/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: music-levels */")
        guard after.count == 2 else {
            XCTFail(language + ": the group music-levels is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: music-levels */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
