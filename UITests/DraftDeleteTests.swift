import XCTest

// A draft deleted from the list on the start screen: a swipe on its row shows `drafts.delete`, a tap on it asks
// in a system alert, and `drafts.deleteConfirm` deletes while `drafts.deleteCancel` keeps. Each test makes two
// drafts, of two-clips-wide and then of text-wide, each left by the tap on `editor.projects`, the first launch
// with `-drafts fresh` and the second with `-drafts kept`. Drafts are read through the line `start.draftsInfo`:
// the two read "2 2+4200+1+1080x30+c 2+4200+0+1080x30+c", newest first, so `drafts.row.2` is the draft of
// two-clips-wide.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/swipeleft()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/swiperight()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielementtypequeryprovider/alerts
// https://developer.apple.com/documentation/xcuiautomation/xcuielementquery/firstmatch
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class DraftDeleteTests: XCTestCase {
    private let twoDraftsInfo = "2 2+4200+1+1080x30+c 2+4200+0+1080x30+c"

    /// The seconds from the tap on `editor.projects` to the start screen, the cover written on the way (E16).
    private let expectedBack = 5.0

    /// E17: the swipe shows `drafts.delete` within 10 seconds, so the wait expects a third of that.
    private let expectedSwipe = 10.0 / 3

    func testASwipeAndAConfirmedDeleteRemoveTheDraftThenTheLastOne() {
        let app = twoDrafts(language: "en")
        swipeToDelete(app, row: 2) { $0.swipeLeft() }
        screenshot("draft-delete-01-swiped")

        deleteAndAnswer(app, "drafts.deleteConfirm")
        waitUntil("no drafts.row.2 after the delete") { !self.element(app, "drafts.row.2").exists }
        XCTAssertTrue(element(app, "drafts.row.1").exists)
        XCTAssertEqual(draftsInfo(app), "1 2+4200+1+1080x30+c")
        screenshot("draft-delete-02-deleted")

        swipeToDelete(app, row: 1) { $0.swipeLeft() }
        deleteAndAnswer(app, "drafts.deleteConfirm")
        waitUntil("no drafts.row.1 after the delete") { !self.element(app, "drafts.row.1").exists }
        XCTAssertEqual(draftsInfo(app), "0")
        XCTAssertFalse(element(app, "drafts.row.2").exists)
        // The start screen as M1 shows it.
        XCTAssertTrue(element(app, "start.title").exists)
        XCTAssertEqual(element(app, "start.newProject").label, "New project")
        XCTAssertTrue(element(app, "start.newProject").isEnabled)
        XCTAssertEqual(element(app, "start.landscape").label, "Landscape 16:9")
        XCTAssertEqual(element(app, "start.portrait").label, "Portrait 9:16")
        XCTAssertTrue(element(app, "start.landscape").isSelected)
        XCTAssertFalse(element(app, "start.portrait").isSelected)
        XCTAssertLessThan(element(app, "start.landscape").frame.minX, element(app, "start.portrait").frame.minX)
    }

    func testCancelInTheAlertKeepsTheDraft() {
        let app = twoDrafts(language: "en")
        swipeToDelete(app, row: 2) { $0.swipeLeft() }

        deleteAndAnswer(app, "drafts.deleteCancel")
        waitUntil("no alert after Cancel") { !app.alerts.firstMatch.exists }
        XCTAssertTrue(element(app, "drafts.row.2").exists)
        XCTAssertEqual(draftsInfo(app), twoDraftsInfo)
    }

    /// A tap on another row after the swipe either closes the swipe or opens that draft: neither deletes.
    func testATapOnAnotherRowAfterTheSwipeDeletesNothing() {
        let app = twoDrafts(language: "en")
        swipeToDelete(app, row: 2) { $0.swipeLeft() }

        element(app, "drafts.row.1").tap()
        waitUntil("the swipe closed or the editor open after the tap on drafts.row.1") {
            self.element(app, "editor.root").exists || !self.element(app, "drafts.delete").exists
        }
        if element(app, "editor.root").exists {
            print("draft-delete: the tap on drafts.row.1 opened the editor, so back first")
            back(app)
        } else {
            print("draft-delete: the tap on drafts.row.1 closed the swipe")
        }
        XCTAssertEqual(draftsInfo(app), twoDraftsInfo)
    }

    /// The row mirrors in Arabic, so its trailing edge is the left one and the swipe goes to the right.
    func testInArabic() {
        let app = twoDrafts(language: "ar")
        swipeToDelete(app, row: 2) { $0.swipeRight() }
        screenshot("draft-delete-01-swiped-ar")
    }

    func testInSwedish() {
        let app = twoDrafts(language: "sv")
        swipeToDelete(app, row: 2) { $0.swipeLeft() }
        screenshot("draft-delete-01-swiped-sv")
    }

    /// The swipe on `drafts.row.<row>` and the wait for `drafts.delete`, printed (E17).
    private func swipeToDelete(_ app: XCUIApplication, row: Int, _ swipe: (XCUIElement) -> Void) {
        let identifier = "drafts.row." + String(row)
        swipe(element(app, identifier))
        waitUntil("drafts.delete after the swipe on " + identifier, expected: expectedSwipe) {
            self.element(app, "drafts.delete").exists
        }
    }

    /// The tap on `drafts.delete`, the wait for the alert, and the tap on its button of that identifier. The
    /// system alert shows each button as a button holding a second button of the same identifier, so the first
    /// match is taken.
    private func deleteAndAnswer(_ app: XCUIApplication, _ answer: String) {
        element(app, "drafts.delete").tap()
        let button = app.alerts.buttons[answer].firstMatch
        waitUntil(answer + " in the alert after the tap on drafts.delete") { button.exists }
        button.tap()
    }

    /// A draft of two-clips-wide and then one of text-wide, each left by the tap on `editor.projects`.
    private func twoDrafts(language: String) -> XCUIApplication {
        var app = startApp(seed: "two-clips-wide", language: language, drafts: "fresh")
        waitForTheEditor(app)
        back(app)
        app.terminate()
        app = startApp(seed: "text-wide", language: language, drafts: "kept")
        waitForTheEditor(app)
        back(app)
        XCTAssertEqual(draftsInfo(app), twoDraftsInfo)
        return app
    }

    /// The tap on `editor.projects` and the wait for the start screen, printed (E16).
    private func back(_ app: XCUIApplication) {
        element(app, "editor.projects").tap()
        waitUntil("start.newProject after the tap on editor.projects", expected: expectedBack) {
            self.element(app, "start.newProject").exists
        }
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: 10) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("draft-delete: start.draftsInfo reads " + label)
        return label
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Reads until the condition holds, for the effect of a launch, a swipe or a tap. It fails only above three
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
        print("draft-delete: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(holds, what)
    }
}
