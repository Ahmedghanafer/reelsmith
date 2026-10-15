import ReelsmithCore
import XCTest

/// Holds the safe area of the Instagram guide in canvas pixels: the 9:16 canvas less 0.14 of its height at the top,
/// 0.35 at the bottom and 0.06 of its width at each side, and none on the 16:9 canvas.
final class InstagramGuideTests: XCTestCase {
    func testTheSafeAreaOfThePortraitCanvas() throws {
        let safe = try XCTUnwrap(InstagramGuide.safeArea(on: .portrait))
        XCTAssertEqual(safe.x, 64.8, accuracy: 0.000001)
        XCTAssertEqual(safe.y, 268.8, accuracy: 0.000001)
        XCTAssertEqual(safe.width, 950.4, accuracy: 0.000001)
        XCTAssertEqual(safe.height, 979.2, accuracy: 0.000001)
    }

    func testTheLandscapeCanvasHasNoSafeArea() {
        XCTAssertNil(InstagramGuide.safeArea(on: .landscape))
    }
}
