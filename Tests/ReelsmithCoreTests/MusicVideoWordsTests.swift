import Foundation
import XCTest

/// The words of the button that takes the sound of a video stand in the group `music-video` of the three word
/// files, and nothing else stands there.
final class MusicVideoWordsTests: XCTestCase {
    func testTheGroupMusicVideoHoldsItsOneKeyInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, ["music.fromVideo"], language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextOfTheGroupMusicVideo() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Use the sound of a video"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/assets/words/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: music-video */")
        guard after.count == 2 else {
            XCTFail(language + ": the group music-video is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: music-video */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
