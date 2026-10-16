import Foundation
import ReelsmithCore
import XCTest

/// The words of the music part stand in the group `add-music` of the three word files, and nothing else stands
/// there. Every key the state of an import can give is in the English file.
final class AddMusicWordsTests: XCTestCase {
    func testTheGroupAddMusicHoldsItsSevenKeysInAllThreeWordFiles() throws {
        let expected = [
            "music.add", "music.replace", "music.remove", "music.copying", "music.notReadable", "music.protected",
            "music.ok",
        ]
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, expected, language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextsOfTheGroupAddMusic() throws {
        XCTAssertEqual(
            try group(of: "en").map { $0.text },
            [
                "Add music from Files", "Choose another file", "Remove the music", "Adding the music",
                "This file cannot be used as music.",
                "This file is protected and cannot go into an exported video. Music without protection works.",
                "OK",
            ])
    }

    func testEveryKeyOfTheImportStateIsInTheEnglishFile() throws {
        let english = try wordKeys(of: "en")
        for key in MusicImport.allWords {
            XCTAssertTrue(english.contains(key), "en: the key " + key + " is missing")
        }
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/assets/words/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: add-music */")
        guard after.count == 2 else {
            XCTFail(language + ": the group add-music is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: add-music */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
