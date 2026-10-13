import XCTest

/// The words of a text bar of the strip and of its two handles are in every word file.
final class TextRowWordsTests: XCTestCase {
    func testTheThreeKeysOfTheTextRowAreInAllThreeWordFiles() throws {
        let expected = ["textRow.bar", "textRow.trimStart", "textRow.trimEnd"]
        for language in ["en", "ar", "sv"] {
            let keys = try wordKeys(of: language)
            for key in expected {
                XCTAssertTrue(keys.contains(key), language + ": " + key)
            }
        }
    }
}
