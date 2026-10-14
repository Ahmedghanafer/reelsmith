import UIKit
import XCTest

// The way back to the projects and the list of drafts on the start screen. Each test starts its first launch
// with `-drafts fresh`, which empties the test folder of drafts, and any later launch with `-drafts kept`.
// Drafts are read through the line `start.draftsInfo`. The seed two-clips-wide is blue 3 seconds, then red 4,
// on the landscape canvas, and text-wide the same clips with one text, so their drafts read
// "2+4200+0+1080x30" and "2+4200+1+1080x30", with "+c" once the cover is written. Places are compared in
// whole points with a room of 1 point.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuidevice/press(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/typetext(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/xcuiautomation/xcuiscreenshotproviding/screenshot()
// https://developer.apple.com/documentation/coregraphics/cgcontext/init(data:width:height:bitspercomponent:bytesperrow:space:bitmapinfo:)-4fkaf
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class DraftListTests: XCTestCase {
    private let blue = (r: 0, g: 0, b: 255)

    /// At 00:00 the blue clip fills the wide picture area, so the share of blue is more than this.
    private let blueOfTheClip = 0.9

    /// The seconds from a change to its frame in the picture area. A wait fails at three times this.
    private let expectedFrame = 3.0

    /// The seconds from the tap on `editor.projects` to the start screen, the cover written on the way (E16).
    private let expectedBack = 5.0

    /// The row of play from left to right.
    private let row = ["editor.projects", "editor.play", "editor.time", "editor.undo", "editor.redo", "editor.save"]

    func testBackListsTheDraftAndATapOnItsRowOpensItAgain() {
        var app = startList(seed: "two-clips-wide", drafts: "fresh")
        assertTheRow(app)
        screenshot("project-list-03-row")

        back(app)
        XCTAssertTrue(element(app, "start.newProject").isEnabled)
        XCTAssertTrue(element(app, "drafts.row.1").exists)
        XCTAssertFalse(element(app, "drafts.row.2").exists)
        XCTAssertEqual(draftsInfo(app), "1 2+4200+0+1080x30+c")
        screenshot("project-list-01-list")

        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "2 clips, 2 files")
        XCTAssertEqual(element(app, "editor.time").label, "00:00 / 00:07")
        XCTAssertFalse(element(app, "editor.undo").isEnabled)
        let found = waitForTheShare(of: blue, "blue", in: element(app, "editor.picture"), moreThan: blueOfTheClip)
        print("project-list: after the open the share of blue is \(found), B \(blueOfTheClip)")
        XCTAssertGreaterThan(found, blueOfTheClip, "blue in the reopened draft")
        screenshot("project-list-02-reopened")
        app.terminate()

        app = startList(seed: "text-wide", drafts: "kept")
        back(app)
        XCTAssertEqual(draftsInfo(app), "2 2+4200+1+1080x30+c 2+4200+0+1080x30+c")
        let first = element(app, "drafts.row.1").frame
        let second = element(app, "drafts.row.2").frame
        print("project-list: drafts.row.1 at \(first) and drafts.row.2 at \(second)")
        XCTAssertEqual(first.height, second.height, accuracy: 1, "two rows of one height")

        // The older draft is that of two-clips-wide, which has no text: no bar and no selected text.
        element(app, "drafts.row.2").tap()
        waitForTheEditor(app)
        XCTAssertEqual(app.staticTexts["editor.textInfo"].label, "none")
        XCTAssertFalse(element(app, "editor.text.1").exists)
    }

    /// The cover is made when the app leaves the active phase, with no tap on `editor.projects`.
    func testTheCoverIsWrittenWhenTheAppLeaves() {
        let app = startList(seed: "two-clips-wide", drafts: "fresh")

        XCUIDevice.shared.press(.home)
        print("project-list: the home button pressed, 5 seconds given to the app as the story says")
        Thread.sleep(forTimeInterval: 5)
        app.terminate()

        let info = draftsInfo(startApp(seed: nil, drafts: "kept"))
        XCTAssertTrue(info.hasSuffix("+c"), info)
    }

    /// Two edits: the red clip deleted, then a text typed and ended by Done. After a relaunch the draft opened
    /// from the list has its history: one undo takes the text away and leaves the one block.
    func testTheUndoHistoryComesBackWithTheDraftAfterARelaunch() {
        var app = startList(seed: "two-clips-wide", playhead: 1200, drafts: "fresh")
        let red = element(app, "editor.clip.2")
        red.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        waitUntil("the red block selected after the tap on it") { red.isSelected }
        element(app, "editor.delete").tap()
        waitUntil("one block after the delete") { !red.exists }

        element(app, "editor.addText").tap()
        let field = app.textViews["text.field"]
        waitUntil("the field after the tap on Text") { field.exists }
        field.tap()
        waitUntil("the keyboard after the tap on the field", expected: 2) { app.keyboards.firstMatch.exists }
        field.typeText("Hi")
        waitUntil("Hi in the value of the field") { field.value as? String == "Hi" }
        element(app, "text.done").tap()
        waitUntil("no text panel after Done") { !self.element(app, "editor.textRegion").exists }
        app.terminate()

        app = startApp(seed: nil, drafts: "kept")
        XCTAssertEqual(draftsInfo(app), "1 1+1800+1+1080x30+.")
        element(app, "drafts.row.1").tap()
        waitForTheEditor(app)
        let undo = element(app, "editor.undo")
        let bar = element(app, "editor.text.1")
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertFalse(element(app, "editor.clip.2").exists)
        XCTAssertTrue(bar.exists)
        XCTAssertTrue(undo.isEnabled, "the history did not come back with the draft")
        bar.tap()
        waitUntil("text 1 in editor.textInfo after the tap on its bar") {
            app.staticTexts["editor.textInfo"].label.hasPrefix("1 ")
        }

        undo.tap()
        waitUntil("no text after the undo") { !bar.exists }
        XCTAssertEqual(app.staticTexts["editor.textInfo"].label, "none")
        XCTAssertTrue(element(app, "editor.clip.1").exists)
        XCTAssertFalse(element(app, "editor.clip.2").exists)
    }

    func testInArabic() {
        let app = twoDrafts(language: "ar")

        for identifier in ["drafts.row.1", "drafts.row.2"] {
            let frame = element(app, identifier).frame
            // The band of 64 points in the middle of the row's height, where the box stands. A column of the box
            // is all black or picture, a column of the date or the length is mostly white.
            let band = CGRect(x: frame.minX, y: frame.midY - 32, width: frame.width, height: 64)
            let columns = notWhiteColumns(in: band)
            let box = columns.filter { $0.share > 0.9 }.map { $0.x }
            let leftEnd = columns.filter { $0.x < Double(frame.minX) + 64 }.map { $0.share }
            let leading = leftEnd.isEmpty ? 1 : leftEnd.reduce(0, +) / Double(leftEnd.count)
            let boxLeft = box.min() ?? 0
            let boxRight = box.max() ?? 0
            print("project-list: \(identifier) in \(frame): columns more than 0.9 not white from x \(boxLeft) to \(boxRight), share not white \(leading) in the 64 points at its left end")
            XCTAssertFalse(box.isEmpty, identifier + ": no cover box")
            XCTAssertGreaterThan(boxLeft, Double(frame.midX), identifier + ": the cover box in the right half of the row")
            XCTAssertEqual(boxRight - boxLeft, 64, accuracy: 3, identifier + ": the box 64 points wide")
            XCTAssertLessThan(leading, 0.1, identifier + ": nothing but the white of the list at the left end")
        }
        screenshot("project-list-01-list-ar")
    }

    func testInSwedish() {
        _ = twoDrafts(language: "sv")

        screenshot("project-list-01-list-sv")
    }

    /// A draft of two-clips-wide and then one of text-wide, each left by the tap on `editor.projects`, so the
    /// start screen shows two rows. In the editor of the first the row of play is read and kept as a picture.
    private func twoDrafts(language: String) -> XCUIApplication {
        var app = startList(seed: "two-clips-wide", language: language, drafts: "fresh")
        assertTheRow(app)
        screenshot("project-list-03-row-" + language)
        back(app)
        app.terminate()
        app = startList(seed: "text-wide", language: language, drafts: "kept")
        back(app)
        XCTAssertEqual(draftsInfo(app), "2 2+4200+1+1080x30+c 2+4200+0+1080x30+c")
        return app
    }

    /// The six controls of the row of play from left to right under the picture, inside the width of the region,
    /// `editor.projects` 44 by 44 points.
    private func assertTheRow(_ app: XCUIApplication) {
        let region = element(app, "editor.previewRegion")
        let picture = region.descendants(matching: .any)["editor.picture"]
        let found = row.map { region.descendants(matching: .any)[$0] }
        for (place, item) in found.enumerated() {
            print("project-list: \(row[place]) at \(item.frame) in a region of \(region.frame)")
            XCTAssertTrue(item.exists, row[place])
            XCTAssertGreaterThanOrEqual(item.frame.minY, picture.frame.maxY - 1, row[place] + " under the picture")
            XCTAssertGreaterThanOrEqual(item.frame.minX, region.frame.minX - 1, row[place] + " inside the region")
            XCTAssertLessThanOrEqual(item.frame.maxX, region.frame.maxX + 1, row[place] + " inside the region")
            if place > 0 {
                XCTAssertGreaterThanOrEqual(
                    item.frame.minX, found[place - 1].frame.maxX - 1, row[place] + " right of " + row[place - 1])
            }
        }
        XCTAssertEqual(found[0].frame.width, 44, accuracy: 1, "editor.projects")
        XCTAssertEqual(found[0].frame.height, 44, accuracy: 1, "editor.projects")
        XCTAssertTrue(found[0].isEnabled)
    }

    /// The tap on `editor.projects` and the wait for the start screen, printed (E16).
    private func back(_ app: XCUIApplication) {
        element(app, "editor.projects").tap()
        waitUntil("start.newProject after the tap on editor.projects", expected: expectedBack) {
            self.element(app, "start.newProject").exists
        }
    }

    /// Starts the app on a seed and waits for the editor: the first seeded start in a fresh simulator writes
    /// the clips first.
    private func startList(
        seed: String, language: String = "en", playhead: Int? = nil, drafts: String
    ) -> XCUIApplication {
        let app = startApp(seed: seed, language: language, playhead: playhead, drafts: drafts)
        waitForTheEditor(app)
        return app
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: 10) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("project-list: start.draftsInfo reads " + label)
        return label
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// For each column of a rectangle of the screen, its x in points and the share, from 0 to 1, of its pixels
    /// that are not white: some channel more than 48 below 255. The cover box is black with the picture fitted
    /// in it, the list around it is white. Every fourth pixel column and every fourth row is read, as the probe
    /// of `share(of:in:)` reads.
    private func notWhiteColumns(in rect: CGRect) -> [(x: Double, share: Double)] {
        let picture = XCUIScreen.main.screenshot().image
        guard let image = picture.cgImage, picture.size.width > 0,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            XCTFail("the probe could not make its bitmap")
            return []
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else {
            XCTFail("the probe could not read its bitmap")
            return []
        }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let scale = Double(image.width) / Double(picture.size.width)
        let left = max(0, Int((Double(rect.minX) * scale).rounded(.up)))
        let right = min(image.width, Int((Double(rect.maxX) * scale).rounded(.down)))
        let top = max(0, Int((Double(rect.minY) * scale).rounded(.up)))
        let bottom = min(image.height, Int((Double(rect.maxY) * scale).rounded(.down)))
        var columns: [(x: Double, share: Double)] = []
        for x in stride(from: left, to: right, by: 4) {
            var read = 0
            var notWhite = 0
            for y in stride(from: top, to: bottom, by: 4) {
                let offset = y * context.bytesPerRow + x * 4
                read += 1
                if Int(bytes[offset]) < 207 || Int(bytes[offset + 1]) < 207 || Int(bytes[offset + 2]) < 207 {
                    notWhite += 1
                }
            }
            if read > 0 {
                columns.append((x: Double(x) / scale, share: Double(notWhite) / Double(read)))
            }
        }
        if columns.isEmpty {
            XCTFail("the probe found no pixel of the rectangle on the screen")
        }
        return columns
    }

    /// No element says when the frame is drawn, so the share is asked again until it is more than wanted.
    /// Prints the seconds it waited, gives up only above three times the expected seconds, and answers the
    /// last share it read.
    private func waitForTheShare(
        of colour: (r: Int, g: Int, b: Int), _ what: String, in picture: XCUIElement, moreThan wanted: Double
    ) -> Double {
        let started = Date()
        var found = share(of: colour, in: picture)
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !(found > wanted) && waited <= first + 3 * expectedFrame {
            Thread.sleep(forTimeInterval: 0.2)
            found = share(of: colour, in: picture)
            waited = Date().timeIntervalSince(started)
        }
        print("project-list: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, for the effect of a launch, a tap or typing. It fails only above three
    /// times the expected seconds: a hosted runner under load can hold the app for seconds.
    private func waitUntil(_ what: String, expected: Double = 1, _ reached: () -> Bool) {
        let started = Date()
        var holds = reached()
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !holds && waited <= first + 3 * expected {
            Thread.sleep(forTimeInterval: 0.2)
            holds = reached()
            waited = Date().timeIntervalSince(started)
        }
        print("project-list: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
