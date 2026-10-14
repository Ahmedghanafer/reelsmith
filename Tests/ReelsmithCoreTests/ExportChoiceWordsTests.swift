import Foundation
import ReelsmithCore
import XCTest

/// The words of the choice of size and rate stand in the group `export-settings` of the three word files, and
/// nothing else stands there.
final class ExportChoiceWordsTests: XCTestCase {
    private let keys = [
        "export.settings", "export.size", "export.rate", "export.size.720", "export.size.1080", "export.size.4K",
        "export.rate.30", "export.rate.60", "export.settings.done",
    ]

    func testTheGroupExportSettingsHoldsItsNineKeysInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let lines = try group(of: language)
            XCTAssertEqual(lines.map { $0.key }, keys, language)
            XCTAssertFalse(lines.contains { $0.text.isEmpty }, language)
        }
    }

    func testTheEnglishTextsOfTheGroupExportSettings() throws {
        XCTAssertEqual(
            try group(of: "en").map { $0.text },
            ["Export settings", "Size", "Frames a second", "720p", "1080p", "4K", "30 fps", "60 fps", "Done"])
    }

    func testEveryNumberOfTheGroupIsWrittenWithTheDigits0To9() throws {
        for language in ["en", "ar", "sv"] {
            for line in try group(of: language) {
                let other = line.text.filter { $0.isNumber && !("0"..."9").contains($0) }
                XCTAssertEqual(other, "", language + ": " + line.key)
            }
        }
    }

    func testEveryKeyOfTheSizesAndTheRatesIsInTheEnglishFile() throws {
        let english = try wordKeys(of: "en")
        for key in ExportSize.allWords + ExportRate.allWords {
            XCTAssertTrue(english.contains(key), "en: the key " + key + " is missing")
        }
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: export-settings */")
        guard after.count == 2 else {
            XCTFail(language + ": the group export-settings is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: export-settings */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
