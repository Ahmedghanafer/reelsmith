import XCTest

// The colours of the picture area, read through the probe `share(of:in:)`, on the seeds
// two-clips-wide (blue 1920 by 1080 for 3 seconds, then red 1080 by 1920 for 4, on the 16:9 canvas),
// two-clips (the same clips on the 9:16 canvas) and three-clips (those two, then green 1080 by 1920
// for 2 seconds, on the 9:16 canvas). A clip that does not fill the canvas stands whole in its
// middle on black and covers 0.316 of it.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
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

    /// Four edits with a picture on the screen: a trim of the end of the last clip, a split and two
    /// deletes. The old picture stays until the new one is there, so no read finds a black area.
    /// At 8 seconds the green block is from x 141 to 261 and its end handle from x 261 to 285.
    func testAnEditNeverLeavesThePictureAreaBlack() {
        let app = startApp(seed: "three-clips", playhead: 4800)
        waitForTheEditor(app)
        let picture = app.descendants(matching: .any)["editor.picture"]
        XCTAssertGreaterThan(waitForTheShare(of: green, "green", in: picture, moreThan: 0.9), 0.9, "green")

        // The trim: the end of green goes from 9 seconds to 8.5 and the playhead stays inside it.
        select(app.descendants(matching: .any)["editor.clip.3"])
        let handle = app.descendants(matching: .any)["editor.trim.end"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        mark("picture-01-edit-trim")
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: -30, dy: 0)))
        var shares = readForHalfASecond(green, "green", in: picture, after: "the trim")
        XCTAssertGreaterThan(shares.min() ?? 0, 0.9, "green after the trim")
        screenshot("picture-04-after-trim")

        // The split: green becomes a part from 7 to 8 seconds and a part from 8 seconds on.
        let split = app.descendants(matching: .any)["editor.split"]
        XCTAssertTrue(split.isEnabled)
        mark("picture-02-edit-split")
        split.tap()
        shares = readForHalfASecond(green, "green", in: picture, after: "the split")
        XCTAssertGreaterThan(shares.min() ?? 0, 0.9, "green after the split")
        screenshot("picture-05-after-split")

        // A delete that leaves green: the first part goes, the playhead goes to the end of the
        // project and the picture is the last frame of the second part.
        let delete = app.descendants(matching: .any)["editor.delete"]
        select(app.descendants(matching: .any)["editor.clip.3"])
        mark("picture-03-edit-delete")
        delete.tap()
        shares = readForHalfASecond(green, "green", in: picture, after: "the delete of a part of green")
        XCTAssertGreaterThan(shares.min() ?? 0, 0.9, "green after the delete")
        screenshot("picture-06-after-delete")

        // A delete that changes the picture: the rest of green goes and the picture is the last
        // frame of red, which fills the area as green did. Black is read here, and then red is
        // waited for. The app lets go of the old picture 15 seconds after a new item at the latest,
        // which is past the limit of the wait, so an old picture that only the limit took away fails.
        select(app.descendants(matching: .any)["editor.clip.3"])
        mark("picture-04-edit-delete-last")
        delete.tap()
        shares = readForHalfASecond(black, "black", in: picture, after: "the delete of the last of green")
        XCTAssertLessThan(shares.max() ?? 1, 0.1, "black after the delete of the last of green")
        print("picture: the app lets go of the old picture 15 seconds after a new item at the latest")
        XCTAssertGreaterThan(waitForTheShare(of: red, "red", in: picture, moreThan: 0.9), 0.9, "red")
        screenshot("picture-07-red-after-delete")
    }

    /// Taps a block a quarter of its width from its left edge, away from the playhead line, and
    /// waits for it to be selected, expected within 1 second and failing only above 3.
    private func select(_ block: XCUIElement) {
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        let started = Date()
        var waited: Double = 0
        while !block.isSelected && waited <= 3 {
            Thread.sleep(forTimeInterval: 0.2)
            waited = Date().timeIntervalSince(started)
        }
        print("picture: waited \(waited) seconds for the block selected, expected 1")
        XCTAssertTrue(block.isSelected)
    }

    /// Reads the share of the colour as often as the probe can for half a second, from the moment
    /// the call of the edit has come back. Prints the count of the reads with the lowest and the
    /// highest share. A read takes a screenshot, so a gap shorter than the time between two reads
    /// can pass unseen.
    private func readForHalfASecond(
        _ colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, after edit: String
    ) -> [Double] {
        let started = Date()
        var shares: [Double] = []
        repeat {
            shares.append(share(of: colour, in: picture))
        } while Date().timeIntervalSince(started) < 0.5
        let took = Date().timeIntervalSince(started)
        print(
            "picture: \(shares.count) reads in \(took) seconds after \(edit), the share of \(what) from \(shares.min() ?? 0) to \(shares.max() ?? 0)"
        )
        return shares
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
