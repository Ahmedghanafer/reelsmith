import XCTest

/// The words of the split and the delete button are in every word file.
final class ToolsWordsTests: XCTestCase {
    func testTheKeysOfTheTwoButtonsAreInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let keys = try wordKeys(of: language)
            XCTAssertTrue(keys.contains("tools.split"), language)
            XCTAssertTrue(keys.contains("tools.delete"), language)
        }
    }
}
