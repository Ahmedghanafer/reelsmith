import XCTest

// The start screen, started with no seed.
//
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
@MainActor
final class StartTests: XCTestCase {
    func testWithNoSeedTheStartScreenShowsWithLandscapeChosen() {
        let app = startApp(seed: nil)

        assertTheStartScreen(app)
        XCTAssertEqual(element(app, "start.title").label, "Reelsmith")
        XCTAssertEqual(element(app, "start.newProject").label, "New project")
        XCTAssertEqual(element(app, "start.landscape").label, "Landscape 16:9")
        XCTAssertEqual(element(app, "start.portrait").label, "Portrait 9:16")
        // The leading shape is first: in English that is the left side.
        XCTAssertLessThan(element(app, "start.landscape").frame.minX, element(app, "start.portrait").frame.minX)
        screenshot("m1-6b-new-project-01-start")
    }

    func testInArabicTheStartScreenShowsItsArabicWordsAndTheShapesChangeSides() {
        let app = startApp(seed: nil, language: "ar")

        assertTheStartScreen(app)
        // The Arabic line of the word file, so the language reached the screen.
        XCTAssertEqual(element(app, "start.newProject").label, "مشروع جديد")
        let landscape = element(app, "start.landscape")
        let portrait = element(app, "start.portrait")
        XCTAssertGreaterThan(landscape.frame.minX, portrait.frame.minX)
        // The numbers keep the digits 0 to 9.
        XCTAssertTrue(landscape.label.contains("16:9"), landscape.label)
        XCTAssertTrue(portrait.label.contains("9:16"), portrait.label)
        screenshot("m1-6b-new-project-01-start-ar")
    }

    func testATapMovesTheChoiceOfTheShapeAndBack() {
        let app = startApp(seed: nil)
        assertTheStartScreen(app)
        let landscape = element(app, "start.landscape")
        let portrait = element(app, "start.portrait")

        // Near the leading edge, inside the padding around the words: the whole shape takes the tap.
        portrait.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5)).tap()
        XCTAssertTrue(portrait.isSelected)
        XCTAssertFalse(landscape.isSelected)
        screenshot("m1-6b-new-project-05-portrait")

        landscape.tap()
        XCTAssertTrue(landscape.isSelected)
        XCTAssertFalse(portrait.isSelected)

        // The app is ended with portrait chosen. Nothing is saved, so the next start has landscape chosen again.
        portrait.tap()
        XCTAssertTrue(portrait.isSelected)
        app.terminate()
        assertTheStartScreen(startApp(seed: nil))
    }

    func testAfterAnEditorOnASeedARelaunchWithNoSeedShowsTheStartScreen() {
        var app = startApp(seed: "two-clips")
        waitForTheEditor(app)
        app.terminate()

        app = startApp(seed: nil)
        // Nothing of the earlier editor, and landscape is the chosen shape again.
        assertTheStartScreen(app)
        screenshot("m1-6b-new-project-04-relaunch")
    }

    /// The title, the two shapes with landscape chosen, the button enabled, and no editor.
    private func assertTheStartScreen(_ app: XCUIApplication) {
        XCTAssertTrue(element(app, "start.newProject").waitForExistence(timeout: 30))
        XCTAssertTrue(element(app, "start.title").exists)
        XCTAssertTrue(element(app, "start.landscape").isSelected)
        XCTAssertFalse(element(app, "start.portrait").isSelected)
        XCTAssertTrue(element(app, "start.portrait").exists)
        XCTAssertTrue(element(app, "start.newProject").isEnabled)
        XCTAssertFalse(element(app, "editor.root").exists)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
