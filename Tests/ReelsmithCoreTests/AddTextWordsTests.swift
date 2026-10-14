import XCTest

/// The words of the text button and of the text panel are in every word file.
final class AddTextWordsTests: XCTestCase {
    func testTheSixKeysOfTheTextPanelAreInAllThreeWordFiles() throws {
        let expected = ["tools.text", "text.tab.type", "text.tab.look", "text.tab.more", "text.done", "text.field"]
        for language in ["en", "ar", "sv"] {
            let keys = try wordKeys(of: language)
            for key in expected {
                XCTAssertTrue(keys.contains(key), language + ": " + key)
            }
        }
    }
}
