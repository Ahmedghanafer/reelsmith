import Foundation
import XCTest

/// The word of the button that folds the frames stands in the group `fold-frames` of the three word files, and
/// nothing else stands there.
final class FoldWordsTests: XCTestCase {
    func testTheGroupFoldFramesHoldsTheKeyToolsFramesInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            XCTAssertEqual(try group(of: language).map { $0.key }, ["tools.frames"], language)
        }
    }

    func testTheTextOfTheGroupFoldFramesInEachLanguage() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Frames"])
        XCTAssertEqual(try group(of: "ar").map { $0.text }, ["الإطارات"])
        XCTAssertEqual(try group(of: "sv").map { $0.text }, ["Bildrutor"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: fold-frames */")
        guard after.count == 2 else {
            XCTFail(language + ": the group fold-frames is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: fold-frames */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
