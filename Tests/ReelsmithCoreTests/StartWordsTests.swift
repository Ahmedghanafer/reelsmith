import ReelsmithCore
import XCTest

/// Holds the word keys of the start screen to the word files.
final class StartWordsTests: XCTestCase {
    func testEveryKeyOfTheStartScreenIsInAllThreeWordFiles() throws {
        let keys = [
            "start.title", "start.newProject", "start.landscape", "start.portrait", "start.copying",
            "start.noneReadable", "start.ok",
        ]
        for language in ["en", "ar", "sv"] {
            let found = try wordKeys(of: language)
            for key in keys {
                XCTAssertTrue(found.contains(key), language + ": the key " + key + " is missing")
            }
        }
    }

    func testEveryKeyOfTheStartStateAndOfTheCanvasIsInTheEnglishFile() throws {
        let english = try wordKeys(of: "en")
        for key in StartState.allWords + Canvas.allWords {
            XCTAssertTrue(english.contains(key), "en: the key " + key + " is missing")
        }
    }
}
