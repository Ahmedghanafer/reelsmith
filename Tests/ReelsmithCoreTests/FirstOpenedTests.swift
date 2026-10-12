import Foundation
import XCTest

@testable import ReelsmithCore

final class FirstOpenedTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    func testFirstRunWritesTheDateToTheFile() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(firstOpened(in: folder, now: now), .date(now))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("first-opened.txt").path))
    }

    func testLaterRunReadsTheDateOfTheFirstRun() {
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        _ = firstOpened(in: folder, now: first)

        XCTAssertEqual(firstOpened(in: folder, now: first.addingTimeInterval(86_400)), .date(first))
    }

    func testFileThatCannotBeWrittenIsUnavailable() {
        let missing = folder.appendingPathComponent("missing")

        XCTAssertEqual(firstOpened(in: missing, now: Date()), .unavailable)
    }

    func testFileThatCannotBeReadIsUnavailable() throws {
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("first-opened.txt"), withIntermediateDirectories: false)

        XCTAssertEqual(firstOpened(in: folder, now: Date()), .unavailable)
    }

    func testFileThatHoldsNoDateIsUnavailableAndLeftUnchanged() throws {
        let file = folder.appendingPathComponent("first-opened.txt")
        try "not a date".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(firstOpened(in: folder, now: Date()), .unavailable)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "not a date")
    }
}
