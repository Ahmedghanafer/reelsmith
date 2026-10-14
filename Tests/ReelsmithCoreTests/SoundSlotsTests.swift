import Foundation
import XCTest

/// Holds the six groups for the words of sound after `text-path` in each word file. What stands inside a group is not read.
final class SoundSlotsTests: XCTestCase {
    func testTheSixSlotsOfSoundFollowTheEndOfTextPathInTheirOrder() throws {
        let topics = ["sound-panel", "sound-clips", "add-music", "music-levels", "music-video", "sound-path"]
        var wanted = ["/* end slot: text-path */"]
        for topic in topics {
            wanted += ["/* slot: " + topic + " */", "/* end slot: " + topic + " */"]
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        for language in ["en", "ar", "sv"] {
            let file = repository.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
            let lines = try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline)
            let marks = lines.map(String.init).filter { $0.contains("slot: ") }
            let start = try XCTUnwrap(marks.firstIndex(of: wanted[0]), language)

            XCTAssertEqual(Array(marks[start...].prefix(wanted.count)), wanted, language)
        }
    }
}
