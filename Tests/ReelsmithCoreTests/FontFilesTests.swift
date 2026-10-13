import Foundation
import XCTest

/// Holds the font folder of the Engine target to its three files, found from the place of this file.
final class FontFilesTests: XCTestCase {
    func testTheFontFolderHoldsTheTwoFacesAndTheirLicenceAndNothingElse() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: fontFolder.path)

        XCTAssertEqual(names.sorted(), ["Amiri-Bold.ttf", "Amiri-Regular.ttf", "OFL.txt"])
    }

    func testTheLicenceTextNamesTheLicenceAndTheAuthors() throws {
        let text = try String(contentsOf: fontFolder.appendingPathComponent("OFL.txt"), encoding: .utf8)

        XCTAssertTrue(text.contains("SIL Open Font License, Version 1.1"))
        XCTAssertTrue(
            text.split(whereSeparator: \.isNewline)
                .contains { $0.hasPrefix("Copyright 2010-2022 The Amiri Project Authors") })
    }
}

private let fontFolder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/ReelsmithEngine/Fonts")
