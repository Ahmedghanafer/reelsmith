import XCTest

// The colours of the picture area, read through the probe `share(of:in:)`, on the seeds
// two-clips-wide (blue 1920 by 1080 for 3 seconds, then red 1080 by 1920 for 4, on the 16:9 canvas),
// two-clips (the same clips on the 9:16 canvas) and three-clips (those two, then green 1080 by 1920
// for 2 seconds, on the 9:16 canvas). A clip that does not fill the canvas stands whole in its
// middle on black and covers 0.316 of it.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class PictureTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)
    private let red = (r: 255, g: 0, b: 0)
    private let green = (r: 0, g: 255, b: 0)
    private let black = (r: 0, g: 0, b: 0)

    /// The seconds from the editor on screen to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    func testOnTheWideCanvasTheBlueClipFillsThePictureArea() {
        let picture = startPicture(seed: "two-clips-wide", playhead: 600)

        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.9), 0.9, "blue")
        XCTAssertLessThan(share(of: red, in: picture), 0.05, "red")
        XCTAssertLessThan(share(of: green, in: picture), 0.05, "green")
        screenshot("picture-01-blue-fills")
    }

    func testOnTheWideCanvasTheRedClipStandsBetweenBlackBars() {
        let picture = startPicture(seed: "two-clips-wide", playhead: 3000)

        // Red is 607.5 by 1080 at 656.25, 0 on the canvas of 1920 by 1080.
        XCTAssertGreaterThan(waitForTheShare(of: red, "red", in: picture, moreThan: 0.2), 0.2, "red")
        XCTAssertLessThan(share(of: red, in: picture), 0.45, "red")
        XCTAssertGreaterThan(share(of: black, in: picture), 0.5, "black")
        XCTAssertLessThan(share(of: blue, in: picture), 0.05, "blue")
        screenshot("picture-02-red-with-bars")
    }

    func testOnThePortraitCanvasBlueStandsBetweenBlackBarsAndRedFills() {
        var picture = startPicture(seed: "two-clips", playhead: 600)

        // Blue is 1080 by 607.5 at 0, 656.25 on the canvas of 1080 by 1920.
        XCTAssertGreaterThan(waitForTheShare(of: blue, "blue", in: picture, moreThan: 0.2), 0.2, "blue")
        XCTAssertLessThan(share(of: blue, in: picture), 0.45, "blue")
        XCTAssertGreaterThan(share(of: black, in: picture), 0.5, "black")
        screenshot("picture-03-portrait")

        picture = startPicture(seed: "two-clips", playhead: 3000)
        XCTAssertGreaterThan(waitForTheShare(of: red, "red", in: picture, moreThan: 0.9), 0.9, "red")
        XCTAssertLessThan(share(of: blue, in: picture), 0.05, "blue")
    }

    func testOnThePortraitCanvasTheGreenClipFillsThePictureArea() {
        // 8 seconds: one second into the green clip, the last of the three.
        let picture = startPicture(seed: "three-clips", playhead: 4800)

        XCTAssertGreaterThan(waitForTheShare(of: green, "green", in: picture, moreThan: 0.9), 0.9, "green")
        XCTAssertLessThan(share(of: red, in: picture), 0.05, "red")
        XCTAssertLessThan(share(of: blue, in: picture), 0.05, "blue")
    }

    /// Starts the app, waits for the editor and gives the picture area: the first seeded start in a
    /// fresh simulator writes the clips first.
    private func startPicture(seed: String, playhead: Int) -> XCUIElement {
        let app = startApp(seed: seed, playhead: playhead)
        waitForTheEditor(app)
        let picture = app.descendants(matching: .any)["editor.picture"]
        XCTAssertTrue(picture.exists)
        return picture
    }

    /// No element says when the frame is drawn, so the share is asked again until it is more than
    /// wanted. Prints the seconds it waited, gives up only above three times the expected seconds,
    /// and answers the last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, moreThan wanted: Double
    ) -> Double {
        let started = Date()
        var waited: Double = 0
        var found = share(of: colour, in: picture)
        while !(found > wanted) && waited <= 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print("picture: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame)")
        return found
    }
}
