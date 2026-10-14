import Foundation
import ReelsmithCore
import XCTest

/// Holds the launch value `-drafts`, `showsInfo` and the folder of the drafts.
final class LaunchDraftsTests: XCTestCase {
    private let support = URL(fileURLWithPath: "/data/Library/Application Support")
    private let caches = URL(fileURLWithPath: "/data/Library/Caches")

    func testDraftsReadsFreshAndKeptAndNothingElse() {
        XCTAssertEqual(LaunchOptions(arguments: ["-drafts", "fresh"]).drafts, .fresh)
        XCTAssertEqual(LaunchOptions(arguments: ["-drafts", "kept"]).drafts, .kept)
        XCTAssertNil(LaunchOptions(arguments: ["-drafts", "other"]).drafts)
        XCTAssertNil(LaunchOptions(arguments: ["-drafts"]).drafts)
        XCTAssertNil(LaunchOptions(arguments: []).drafts)
    }

    func testShowsInfoWithASeedOrDrafts() {
        XCTAssertTrue(LaunchOptions(arguments: ["-seed", "text-wide"]).showsInfo)
        XCTAssertTrue(LaunchOptions(arguments: ["-drafts", "fresh"]).showsInfo)
        XCTAssertTrue(LaunchOptions(arguments: ["-seed", "text-wide", "-drafts", "kept"]).showsInfo)
        XCTAssertFalse(LaunchOptions(arguments: []).showsInfo)
    }

    func testTheFolderOfTheDrafts() {
        let test = LaunchOptions(arguments: ["-drafts", "kept"]).draftsFolder(applicationSupport: support, caches: caches)
        let hers = LaunchOptions(arguments: []).draftsFolder(applicationSupport: support, caches: caches)

        XCTAssertEqual(test.path, "/data/Library/Caches/TestDrafts")
        XCTAssertEqual(hers.path, "/data/Library/Application Support/Drafts")
    }
}
