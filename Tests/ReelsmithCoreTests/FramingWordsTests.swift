import Foundation
import XCTest

/// The words of the framing row stand in the group `framing` of the three word files, and nothing else stands there.
final class FramingWordsTests: XCTestCase {
    func testTheGroupFramingHoldsItsFourKeysInAllThreeWordFiles() throws {
        for language in ["en", "ar", "sv"] {
            XCTAssertEqual(
                try group(of: language).map { $0.key }, ["clip.fit", "clip.fill", "clip.blur", "clip.applyAll"],
                language)
        }
    }

    func testTheTextOfTheGroupFramingInEachLanguage() throws {
        XCTAssertEqual(try group(of: "en").map { $0.text }, ["Fit", "Fill", "Blur", "All clips"])
        XCTAssertEqual(try group(of: "ar").map { $0.text }, ["ملاءمة", "ملء", "تمويه", "كل المقاطع"])
        XCTAssertEqual(try group(of: "sv").map { $0.text }, ["Anpassa", "Fyll", "Oskärpa", "Alla klipp"])
    }

    /// The lines between the two markers of the group in the word file of one language, in their order.
    private func group(of language: String) throws -> [(key: String, text: String)] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
        let content = try String(contentsOf: file, encoding: .utf8)
        let after = content.components(separatedBy: "/* slot: framing */")
        guard after.count == 2 else {
            XCTFail(language + ": the group framing is not there once")
            return []
        }
        let inside = after[1].components(separatedBy: "/* end slot: framing */")[0]
        return inside.split(whereSeparator: { $0.isNewline }).map { line in
            let pieces = String(line).components(separatedBy: "\"")
            return (key: pieces.count > 1 ? pieces[1] : "", text: pieces.count > 3 ? pieces[3] : "")
        }
    }
}
