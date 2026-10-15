import XCTest

// The lifted block. While a press runs the pressed block is drawn under the finger, which no UI test can read:
// the recording of the walk shows it. These tests hold what stands after the press. On `three-clips` at 5.5
// seconds (`-playhead 3300`) red's left end is at x 51 and green's middle at x 351, and at 60 points a second
// blue is 180 points wide, red 240 and green 120. Each test starts with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:thendragto:withvelocity:thenholdforduration:)
// https://developer.apple.com/documentation/xctest/xcuigesturevelocity
// https://developer.apple.com/documentation/xctest/xcuicoordinate/press(forduration:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
// https://developer.apple.com/documentation/xctest/xcuielementattributes/value
@MainActor
final class LiftTests: XCTestCase {
    private let blue = "blue 0+1800 100 v"
    private let red = "red 0+2400 100 v"
    private let green = "green 0+1200 100 v"
    /// The width of each block by the media of its clip.
    private let widths: [String: CGFloat] = ["blue": 180, "red": 240, "green": 120]

    /// The walk: green pressed at its middle for 0.6 seconds, dragged in about 1.5 seconds to 4 points right of the
    /// left end of red and held there 1 second. The drop place is the one of a move without the lift.
    func testTheWalkPutsGreenSecondAndNoBlockStaysLifted() {
        let app = startLift()
        let greenBlock = element(app, "editor.clip.3")
        let redBlock = element(app, "editor.clip.2")
        print("lift: editor.clip.3 hittable at the press: \(greenBlock.isHittable), its frame \(greenBlock.frame)")
        print("lift: editor.clip.2 frame before the press \(redBlock.frame)")
        let from = greenBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = redBlock.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 4, dy: 0))

        mark("lift-01-walk")
        // 296 points at 200 points a second.
        from.press(forDuration: 0.6, thenDragTo: to, withVelocity: XCUIGestureVelocity(rawValue: 200), thenHoldForDuration: 1)
        waitUntil("editor.clip.2 reading green after the walk", expected: 1, limit: 10) {
            self.value(app, 2) == self.green
        }
        XCTAssertEqual(values(app), [blue, green, red])
        waitUntil("every block 56 high and as wide as its clip after the walk") { self.atTheirSizes(app) }
        screenshot("lift-01-dropped")
    }

    /// Green selected first, then the same walk. While green is lifted no trim handle is shown, which only the
    /// recording shows. After the drop green is still selected and both handles are at its new ends.
    func testTheHandlesOfASelectedBlockComeBackAtItsNewEnds() {
        let app = startLift()
        let greenBlock = element(app, "editor.clip.3")
        greenBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("both handles at the ends of green after the tap") { self.handlesAreAtTheEnds(app, of: greenBlock) }
        let redBlock = element(app, "editor.clip.2")
        print("lift: editor.clip.3 frame at the press \(greenBlock.frame), editor.clip.2 frame \(redBlock.frame)")
        let from = greenBlock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = redBlock.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 4, dy: 0))

        mark("lift-02-selected-walk")
        from.press(forDuration: 0.6, thenDragTo: to, withVelocity: XCUIGestureVelocity(rawValue: 200), thenHoldForDuration: 1)
        waitUntil("editor.clip.2 reading green after the walk", expected: 1, limit: 10) {
            self.value(app, 2) == self.green
        }
        XCTAssertEqual(values(app), [blue, green, red])
        waitUntil("both handles at the new ends of green after the drop") {
            self.handlesAreAtTheEnds(app, of: self.element(app, "editor.clip.2"))
        }
        screenshot("lift-02-handles-back")
    }

    /// A press held still for 1 second and lifted moves nothing and leaves no block lifted.
    func testAPressHeldStillAndLiftedMovesNothing() {
        let app = startLift()
        let undo = element(app, "editor.undo")
        XCTAssertFalse(undo.isEnabled)

        element(app, "editor.clip.3").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1)
        waitUntil("every block 56 high and as wide as its clip after the press") { self.atTheirSizes(app) }
        XCTAssertEqual(values(app), [blue, red, green])
        XCTAssertFalse(undo.isEnabled)
    }

    /// Whether each block is 56 points high and as wide as its clip at 60 points a second, within 1 point. A lifted
    /// block is drawn larger, so it is not at its size.
    private func atTheirSizes(_ app: XCUIApplication) -> Bool {
        var all = true
        for position in 1...3 {
            let block = element(app, "editor.clip." + String(position))
            let media = String(value(app, position).prefix(while: { $0 != " " }))
            let frame = block.frame
            print("lift: editor.clip.\(position) is \(media), its frame \(frame)")
            guard let width = widths[media] else {
                all = false
                continue
            }
            if abs(frame.height - 56) > 1 || abs(frame.width - width) > 1 {
                all = false
            }
        }
        return all
    }

    /// Whether both handles are shown, the start handle ending where the block starts and the end handle starting
    /// where it ends, within 1 point.
    private func handlesAreAtTheEnds(_ app: XCUIApplication, of block: XCUIElement) -> Bool {
        let start = element(app, "editor.trim.start")
        let end = element(app, "editor.trim.end")
        guard start.exists, end.exists else {
            print("lift: a handle is not shown, the block's frame \(block.frame)")
            return false
        }
        print("lift: handles \(start.frame) and \(end.frame), the block's frame \(block.frame)")
        return abs(start.frame.maxX - block.frame.minX) <= 1 && abs(end.frame.minX - block.frame.maxX) <= 1
    }

    private func startLift() -> XCUIApplication {
        let app = startApp(seed: "three-clips", playhead: 3300, drafts: "fresh")
        waitForTheEditor(app)
        return app
    }

    /// Reads until the condition holds, for the effect of a press or a launch. It is expected within the seconds
    /// given and fails only above the limit, which counts from the end of the first read.
    private func waitUntil(_ what: String, expected: Double = 1, limit: Double = 3, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        let first = waited
        while !holds && waited <= first + limit {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("lift: waited \(waited) seconds for \(what), expected \(expected), limit \(limit)")
        XCTAssertTrue(holds, what)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The value of the block at the position, empty when there is none.
    private func value(_ app: XCUIApplication, _ position: Int) -> String {
        element(app, "editor.clip." + String(position)).value as? String ?? ""
    }

    private func values(_ app: XCUIApplication) -> [String] {
        [value(app, 1), value(app, 2), value(app, 3)]
    }
}
