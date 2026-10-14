import Foundation
import XCTest

/// The words of the part clips of the sound panel, its slider and its toggle, stand in the group `sound-clips`
/// of the three word files, and nothing else stands there.
final class SoundClipsWordsTests: XCTestCase {
    func testTheGroupSoundClipsHoldsItsTwoKeysInAllThreeWordFiles() throws {
        let expected = ["sound.clipVolume", "sound.clipsMuted"]
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, expected, language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextsOfTheGroupSoundClips() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Clip sound", "Mute the clips"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: sound-clips */")
        guard after.count == 2 else {
            XCTFail(language + ": the group sound-clips is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: sound-clips */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
