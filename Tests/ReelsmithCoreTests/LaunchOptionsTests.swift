import ReelsmithCore
import XCTest

final class LaunchOptionsTests: XCTestCase {
    func testAnEmptyListGivesNoSeedNoPlayheadAndNoExportFailure() {
        let options = LaunchOptions(arguments: [])

        XCTAssertNil(options.seed)
        XCTAssertNil(options.playhead)
        XCTAssertFalse(options.exportFails)
    }

    func testSeedReadsTheNameOfASeed() {
        XCTAssertEqual(LaunchOptions(arguments: ["-seed", "two-clips"]).seed, .twoClips)
    }

    func testAnUnknownSeedNameGivesNil() {
        XCTAssertNil(LaunchOptions(arguments: ["-seed", "four-clips"]).seed)
    }

    func testPlayheadReadsTicks() {
        XCTAssertEqual(LaunchOptions(arguments: ["-playhead", "3000"]).playhead, Time(ticks: 3000))
    }

    func testExportFailsIsTrueWhenNamed() {
        XCTAssertTrue(LaunchOptions(arguments: ["-export-fails"]).exportFails)
    }

    func testTheThreeValuesAreReadTogetherAmongOtherArguments() {
        let options = LaunchOptions(arguments: [
            "/path/Reelsmith", "-AppleLanguages", "(ar)", "-AppleLocale", "ar", "-seed", "three-clips", "-playhead",
            "1800", "-export-fails",
        ])

        XCTAssertEqual(options.seed, .threeClips)
        XCTAssertEqual(options.playhead, Time(ticks: 1800))
        XCTAssertTrue(options.exportFails)
    }

    func testAValueThatIsMissingOrNoNumberGivesNil() {
        XCTAssertNil(LaunchOptions(arguments: ["-seed"]).seed)
        XCTAssertNil(LaunchOptions(arguments: ["-playhead"]).playhead)
        XCTAssertNil(LaunchOptions(arguments: ["-playhead", "soon"]).playhead)
    }

    func testNoOtherLaunchValueExists() {
        XCTAssertEqual(
            LaunchOptions(arguments: ["-export-succeeds", "-selection", "1", "two-clips", "3000"]),
            LaunchOptions(arguments: []))
    }
}
