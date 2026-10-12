import ReelsmithCore
import XCTest

/// Holds the word keys of the export button and its panel to the word files.
final class ExportWordsTests: XCTestCase {
    func testEveryKeyOfTheExportIsInAllThreeWordFiles() throws {
        let keys = [
            "export.button", "export.exporting", "export.saved", "export.done", "export.failed",
            "export.notAllowed", "export.close",
        ]
        for language in ["en", "ar", "sv"] {
            let found = try wordKeys(of: language)
            for key in keys {
                XCTAssertTrue(found.contains(key), language + ": the key " + key + " is missing")
            }
        }
    }

    func testEveryKeyOfTheExportStateIsInTheEnglishFile() throws {
        let english = try wordKeys(of: "en")
        for key in ExportState.allWords {
            XCTAssertTrue(english.contains(key), "en: the key " + key + " is missing")
        }
    }
}
