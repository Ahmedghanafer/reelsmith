import XCTest

/// The accessibility words of the play button are in every word file.
final class PreviewWordsTests: XCTestCase {
    func testTheKeysOfPlayAndPauseAreInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            let keys = try wordKeys(of: language)
            XCTAssertTrue(keys.contains("preview.play"), language)
            XCTAssertTrue(keys.contains("preview.pause"), language)
        }
    }
}
