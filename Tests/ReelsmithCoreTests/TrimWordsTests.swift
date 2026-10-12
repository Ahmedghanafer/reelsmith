import XCTest

/// The accessibility words of the two trim handles are in every word file.
final class TrimWordsTests: XCTestCase {
    func testTheKeysOfTheTwoHandlesAreInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let keys = try wordKeys(of: language)
            XCTAssertTrue(keys.contains("trim.start"), language)
            XCTAssertTrue(keys.contains("trim.end"), language)
        }
    }
}
