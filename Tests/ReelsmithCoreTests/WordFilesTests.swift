import Foundation
import XCTest

/// Holds the three word files `App/Resources/<en, ar, sv>.lproj/Localizable.strings` to the same keys.
final class WordFilesTests: XCTestCase {
    func testTheWordFilesOfTheRepositoryAgree() throws {
        XCTAssertEqual(try wordFileProblems(in: repository), [])
    }

    func testTheKeyOfTheSeedTextIsInTheEnglishFile() throws {
        XCTAssertTrue(try wordKeys(of: "en").contains("editor.seedInfo"))
    }

    func testWordFilesThatAgreeHaveNoProblem() throws {
        let folder = try makeWordFiles(
            en: "/* slot: one */\n\"a.title\" = \"Title\";\n\"a.count\" = \"%1$@ of %2$@\";\n/* end slot: one */\n",
            ar: "/* slot: one */\n\"a.title\" = \"عنوان\";\n\"a.count\" = \"%2$@ من %1$@\";\n/* end slot: one */\n",
            sv: "/* slot: one */\n\"a.title\" = \"Rubrik\";\n\"a.count\" = \"%1$@ av %2$@\";\n/* end slot: one */\n")

        XCTAssertEqual(try wordFileProblems(in: folder), [])
    }

    func testAKeyThatOneFileLacksFails() throws {
        let folder = try makeWordFiles(
            en: "\"a.title\" = \"Title\";\n\"a.done\" = \"Done\";\n",
            ar: "\"a.title\" = \"عنوان\";\n",
            sv: "\"a.title\" = \"Rubrik\";\n\"a.done\" = \"Klar\";\n")

        XCTAssertEqual(try wordFileProblems(in: folder), ["ar: the key a.done is missing"])
    }

    func testAnEmptyTextFails() throws {
        let folder = try makeWordFiles(
            en: "\"a.title\" = \"Title\";\n",
            ar: "\"a.title\" = \"عنوان\";\n",
            sv: "\"a.title\" = \"\";\n")

        XCTAssertEqual(try wordFileProblems(in: folder), ["sv: the text of a.title is empty"])
    }

    func testPlaceholdersThatDifferBetweenLanguagesFail() throws {
        let folder = try makeWordFiles(
            en: "\"a.count\" = \"%1$@ of %2$@\";\n",
            ar: "\"a.count\" = \"%1$@ من\";\n",
            sv: "\"a.count\" = \"%1$@ av %2$@\";\n")

        XCTAssertEqual(try wordFileProblems(in: folder), ["ar: the placeholders of a.count differ from en"])
    }

    func testAKeyThatAppearsTwiceFails() throws {
        let folder = try makeWordFiles(
            en: "\"a.title\" = \"Title\";\n\"a.title\" = \"Heading\";\n",
            ar: "\"a.title\" = \"عنوان\";\n",
            sv: "\"a.title\" = \"Rubrik\";\n")

        XCTAssertEqual(try wordFileProblems(in: folder), ["en: the key a.title appears twice"])
    }

    /// Writes three word files under a new folder, laid out as in the repository, and returns the folder.
    private func makeWordFiles(en: String, ar: String, sv: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        for (language, content) in [("en", en), ("ar", ar), ("sv", sv)] {
            let file = wordFile(of: language, in: folder)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        return folder
    }
}

private let wordLanguages = ["en", "ar", "sv"]

private let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private func wordFile(of language: String, in folder: URL) -> URL {
    folder.appendingPathComponent("App/Resources/" + language + ".lproj/Localizable.strings")
}

/// The keys of the word file of one language ("en", "ar" or "sv") in the repository, in the order of the file.
/// For the tests of other stories, which hold the keys a Core state can give to the English file.
func wordKeys(of language: String) throws -> [String] {
    let content = try String(contentsOf: wordFile(of: language, in: repository), encoding: .utf8)
    return try XCTUnwrap(wordLines(of: content)).map { $0.key }
}

/// Everything wrong with the three word files under a folder, one line each. Empty when they agree.
private func wordFileProblems(in repository: URL) throws -> [String] {
    var problems: [String] = []
    var texts: [String: [String: String]] = [:]
    for language in wordLanguages {
        let content = try String(contentsOf: wordFile(of: language, in: repository), encoding: .utf8)
        guard let lines = wordLines(of: content) else {
            problems.append(language + ": the file holds something that is no comment and no line of a key")
            continue
        }
        var found: [String: String] = [:]
        for line in lines {
            if found[line.key] != nil {
                problems.append(language + ": the key " + line.key + " appears twice")
            }
            if line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problems.append(language + ": the text of " + line.key + " is empty")
            }
            found[line.key] = line.text
        }
        texts[language] = found
    }

    let allKeys = Set(texts.values.flatMap { $0.keys }).sorted()
    for key in allKeys {
        for language in wordLanguages where texts[language] != nil && texts[language]?[key] == nil {
            problems.append(language + ": the key " + key + " is missing")
        }
        guard let english = texts["en"]?[key] else { continue }
        for language in wordLanguages {
            if let text = texts[language]?[key], placeholders(of: text) != placeholders(of: english) {
                problems.append(language + ": the placeholders of " + key + " differ from en")
            }
        }
    }
    return problems
}

/// The lines of a word file in order, each a key with its text, comments left out.
/// Nil when anything else stands in the file.
private func wordLines(of content: String) -> [(key: String, text: String)]? {
    let characters = Array(content)
    var index = 0
    var lines: [(key: String, text: String)] = []

    func skipSpaceAndComments() -> Bool {
        while index < characters.count {
            if characters[index].isWhitespace {
                index += 1
            } else if characters[index] == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                index += 2
                while index + 1 < characters.count, !(characters[index] == "*" && characters[index + 1] == "/") {
                    index += 1
                }
                guard index + 1 < characters.count else { return false }
                index += 2
            } else {
                return true
            }
        }
        return true
    }

    func quoted() -> String? {
        guard index < characters.count, characters[index] == "\"" else { return nil }
        index += 1
        var value = ""
        while index < characters.count, characters[index] != "\"" {
            if characters[index] == "\\" {
                index += 1
                guard index < characters.count else { return nil }
            }
            value.append(characters[index])
            index += 1
        }
        guard index < characters.count else { return nil }
        index += 1
        return value
    }

    func mark(_ character: Character) -> Bool {
        guard skipSpaceAndComments(), index < characters.count, characters[index] == character else { return false }
        index += 1
        return skipSpaceAndComments()
    }

    while true {
        guard skipSpaceAndComments() else { return nil }
        if index == characters.count { return lines }
        guard let key = quoted(), mark("="), let text = quoted(), mark(";") else { return nil }
        lines.append((key: key, text: text))
    }
}

/// The placeholders of a text, such as `%1$@`, sorted, so the order in the sentence may differ between languages.
private func placeholders(of text: String) -> [String] {
    let characters = Array(text)
    let digits: ClosedRange<Character> = "0"..."9"
    var found: [String] = []
    var index = 0
    while index < characters.count {
        guard characters[index] == "%" else {
            index += 1
            continue
        }
        var end = index + 1
        while end < characters.count, digits.contains(characters[end]) || characters[end] == "$" {
            end += 1
        }
        if end < characters.count, !(end == index + 1 && characters[end] == "%") {
            found.append(String(characters[index...end]))
        }
        index = end + 1
    }
    return found.sorted()
}
