import XCTest

// Adding clips: the button `editor.addClips` at the trailing end of the tools row, the picker with photos, a pick
// of the test photo and red added to an open draft, a cancelled picker, the photo of photo-wide in the picture, and
// a new project with the photo alone. The library holds blue, red and the test photo magenta, so the grid counts
// blue 1, red 2 and the photo 3 from its end once the simulator's own photos are skipped (`chooseInThePhotoPicker`
// with `photos: true`). A clip is read by the value of its block, which ends " v" for a video and " p" for a
// photo. A draft is read through `start.draftsInfo`. Every test starts its first launch with `-drafts fresh`.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/xctest/xcuielementsnapshotproviding/snapshot()
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class AddClipsTests: XCTestCase {
    /// The seconds from the tap on the right of the picker's bar to the clips in the editor: a copy and the still
    /// movie of a photo.
    private let expectedCopy = 20.0

    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    /// The seconds for a frame of the picture to be drawn.
    private let expectedFrame = 5.0

    func testAddStandsAtTheTrailingEndOfTheToolsRowAfterTheFourButtons() {
        let app = startApp(seed: "two-clips-wide", drafts: "fresh")
        waitForTheEditor(app)
        let add = element(app, "editor.addClips")
        XCTAssertTrue(add.exists)
        XCTAssertTrue(add.isHittable)
        XCTAssertTrue(add.isEnabled)
        XCTAssertEqual(Double(add.frame.width), 44, accuracy: 1)
        XCTAssertEqual(Double(add.frame.height), 44, accuracy: 1)
        let order = ["editor.split", "editor.delete", "editor.addText", "editor.sound", "editor.addClips"]
        assertTheRow(app, leftToRight: order)
    }

    func testAPickOfThePhotoThenRedAddsTwoClipsToTheOpenDraft() {
        var app = startApp(seed: "two-clips-wide", drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "2 clips, 2 files")
        element(app, "editor.addClips").tap()
        let stopped = chooseInThePhotoPicker(app, fromTheEnd: [3, 2], confirms: true, picture: nil, photos: true)
        XCTAssertNil(stopped, stopped ?? "")
        waitUntil("4 clips, 4 files in editor.seedInfo after the picker", expected: expectedCopy) {
            app.staticTexts["editor.seedInfo"].label == "4 clips, 4 files"
        }
        let photo = value(app, "editor.clip.3")
        let red = value(app, "editor.clip.4")
        print("add-clips: editor.clip.3 reads " + photo + ", editor.clip.4 reads " + red)
        XCTAssertTrue(photo.hasSuffix("0+1800 100 p"), photo)
        XCTAssertTrue(red.hasSuffix("0+2400 100 v"), red)
        XCTAssertTrue(element(app, "editor.addClips").isEnabled)
        screenshot("add-clips-01-added")

        // The app ended: the draft holds the four clips, 8400 ticks.
        app.terminate()
        app = startApp(seed: nil, drafts: "kept")
        XCTAssertEqual(draftsInfo(app), "1 4+8400+0+1080x30+.")
        app.terminate()

        // The same editor in Arabic, where Add is the leftmost button, and in Swedish.
        for language in ["ar", "sv"] {
            app = startApp(seed: nil, language: language, drafts: "kept")
            XCTAssertEqual(draftsInfo(app), "1 4+8400+0+1080x30+.")
            element(app, "drafts.row.1").tap()
            waitForTheEditor(app)
            // editor.seedInfo is in the words of the language, so the reopened draft is read by its blocks.
            waitUntil("the photo third and red fourth in the reopened draft") {
                self.value(app, "editor.clip.3").hasSuffix("0+1800 100 p")
                    && self.value(app, "editor.clip.4").hasSuffix("0+2400 100 v")
                    && !self.element(app, "editor.clip.5").exists
            }
            print("add-clips: editor.seedInfo of the reopened draft reads " + app.staticTexts["editor.seedInfo"].label)
            let order = ["editor.split", "editor.delete", "editor.addText", "editor.sound", "editor.addClips"]
            assertTheRow(app, leftToRight: language == "ar" ? Array(order.reversed()) : order)
            screenshot("add-clips-01-added-" + language)
            app.terminate()
        }
    }

    func testACancelledPickerAddsNothing() {
        var app = startApp(seed: "two-clips-wide", drafts: "fresh")
        waitForTheEditor(app)
        let add = element(app, "editor.addClips")
        add.tap()
        let cell = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        let began = Date()
        let opened = cell.waitForExistence(timeout: 40)
        print("add-clips: waited \(Date().timeIntervalSince(began)) seconds for the picker's grid, expected 10, limit 40")
        XCTAssertTrue(opened, "no cell of the picker's grid came")
        let stopped = cancelThePicker(app)
        XCTAssertNil(stopped, stopped ?? "")
        waitUntil("editor.addClips hittable after the cancel", expected: 2) { add.exists && add.isHittable }
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "2 clips, 2 files")
        XCTAssertFalse(element(app, "editor.clip.3").exists)
        XCTAssertTrue(add.isEnabled)

        app.terminate()
        app = startApp(seed: nil, drafts: "kept")
        XCTAssertEqual(draftsInfo(app), "1 2+4200+0+1080x30+.")
    }

    func testThePhotoOfPhotoWideFillsItsPlaceInThePicture() {
        let app = startApp(seed: "photo-wide", playhead: 2700, drafts: "fresh")
        waitForTheEditor(app)
        XCTAssertEqual(app.staticTexts["editor.seedInfo"].label, "3 clips, 3 files")
        let picture = element(app, "editor.picture")
        XCTAssertTrue(picture.exists)
        let found = waitForTheShare(of: (r: 255, g: 0, b: 255), "magenta", in: picture, moreThan: 0.3)
        XCTAssertGreaterThan(found, 0.3)
    }

    func testANewProjectWithThePhotoAloneOpensWithOnePhotoClip() {
        let app = startApp(seed: nil, drafts: "fresh")
        XCTAssertEqual(draftsInfo(app), "0")
        XCTAssertTrue(element(app, "start.landscape").isSelected)
        element(app, "start.newProject").tap()
        let stopped = chooseInThePhotoPicker(app, fromTheEnd: [3], confirms: true, picture: nil, photos: true)
        XCTAssertNil(stopped, stopped ?? "")
        let began = Date()
        let opened = element(app, "editor.root").waitForExistence(timeout: 3 * expectedCopy)
        print("add-clips: waited \(Date().timeIntervalSince(began)) seconds for editor.root after the picker, expected \(expectedCopy), limit \(3 * expectedCopy)")
        XCTAssertTrue(opened)
        waitUntil("1 clips, 1 files in editor.seedInfo") {
            app.staticTexts["editor.seedInfo"].label == "1 clips, 1 files"
        }
        let photo = value(app, "editor.clip.1")
        print("add-clips: editor.clip.1 reads " + photo)
        XCTAssertTrue(photo.hasSuffix("0+1800 100 p"), photo)
        XCTAssertFalse(element(app, "editor.clip.2").exists)
    }

    /// The buttons stand in one row in this order from left to right, none on another.
    private func assertTheRow(_ app: XCUIApplication, leftToRight identifiers: [String]) {
        let frames = identifiers.map { element(app, $0).frame }
        for (index, frame) in frames.enumerated() {
            print("add-clips: " + identifiers[index] + " at \(frame)")
            XCTAssertEqual(Double(frame.midY), Double(frames[0].midY), accuracy: 2, identifiers[index] + " in the row")
            if index > 0 {
                XCTAssertLessThan(frames[index - 1].maxX, frame.minX, identifiers[index] + " after the one before")
            }
        }
    }

    /// Taps the control on the left of the picker's bar, found by place and by no word: of the small elements in
    /// the row of the topmost button above the grid, the one furthest to the left, when it lies in the left third
    /// of the screen. Nil when tapped, else the step that found nothing.
    private func cancelThePicker(_ app: XCUIApplication) -> String? {
        guard let tree = try? app.snapshot() else {
            return "no snapshot of the picker could be taken"
        }
        let all = flattened(tree).filter {
            !$0.identifier.hasPrefix("start.") && !$0.identifier.hasPrefix("editor.") && $0.frame.width > 1
        }
        let top = all.filter { $0.elementType == .image && $0.identifier == "PXGGridLayout-Info" }
            .map { $0.frame.minY }.min() ?? 0
        let bar = all.filter { $0.elementType == .button && $0.frame.midY < top }
            .min { $0.frame.minY < $1.frame.minY }
        guard let bar else {
            return "no button above the picker's grid was found"
        }
        let cancel = all.filter { abs($0.frame.midY - bar.frame.midY) <= 24 && $0.frame.width <= 120 }
            .filter { $0.frame.midX < tree.frame.width / 3 }
            .min { $0.frame.minX < $1.frame.minX }
        guard let cancel else {
            return "no element was found on the left of the picker's bar"
        }
        print("add-clips: tapped to cancel, kind \(cancel.elementType.rawValue) at \(cancel.frame): " + cancel.label)
        tap(app, theMiddleOf: cancel.frame)
        return nil
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: expectedStart) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("add-clips: start.draftsInfo reads " + label)
        return label
    }

    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        element(app, identifier).value as? String ?? ""
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
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
        print("add-clips: waited \(waited) seconds for a share of \(what) above \(wanted), found \(found), expected \(expectedFrame), limit \(3 * expectedFrame)")
        return found
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds.
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
        print("add-clips: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
