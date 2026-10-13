import ReelsmithCore
import XCTest

/// The words of the look of a text, its faces, its colours and its size, are in the word files.
final class TextLookWordsTests: XCTestCase {
    func testTheFiveKeysOfTheLookAreInAllThreeWordFiles() throws {
        let expected = ["text.font.naskh", "text.font.naskhBold", "text.font.system", "text.colour", "text.size"]
        for language in ["en", "ar", "sv"] {
            let keys = try wordKeys(of: language)
            for key in expected {
                XCTAssertTrue(keys.contains(key), language + ": " + key)
            }
        }
    }

    func testEveryKeyOfTheFacesIsInTheEnglishWordFile() throws {
        let keys = try wordKeys(of: "en")
        for key in TextFont.allWords {
            XCTAssertTrue(keys.contains(key), key)
        }
    }
}
