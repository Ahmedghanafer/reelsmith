import XCTest

// The start screen, started with no seed, and one try at the system photo picker.
//
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xctest/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xctest/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xctest/xcuielementtypequeryprovider
// https://developer.apple.com/documentation/xctest/xcuielementquery/allelementsboundbyindex
// https://developer.apple.com/documentation/xctest/xcuielementquery/matching(identifier:)
// https://developer.apple.com/documentation/xctest/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xctest/xctexpectfailure(_:options:)
// https://developer.apple.com/documentation/xctest/xctexpectedfailure/options/isstrict
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
        XCTAssertTrue(element(app, "editor.root").waitForExistence(timeout: 60))
        app.terminate()

        app = startApp(seed: nil)
        // Nothing of the earlier editor, and landscape is the chosen shape again.
        assertTheStartScreen(app)
        screenshot("m1-6b-new-project-04-relaunch")
    }

    func testOneTryAtTheSystemPicker() {
        // The try cannot fail the run: whatever goes wrong in it is an expected failure, and none is fine too.
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("The one try at the system picker never fails the run.", options: options)

        let stopped = tryThePicker()
        if let stopped {
            print("m1-6b-new-project: picker not driven: " + stopped)
        } else {
            print("m1-6b-new-project: picker driven")
        }
    }

    /// Opens the picker, chooses the first two videos and confirms. Nil when the editor opened, else where it stopped.
    /// The controls of the system picker carry no identifier of ours, so they are found by kind and place.
    private func tryThePicker() -> String? {
        let app = startApp(seed: nil)
        let newProject = element(app, "start.newProject")
        guard newProject.waitForExistence(timeout: 30) else {
            return "the start screen did not show"
        }
        mark("m1-6b-new-project-01-picker")
        newProject.tap()

        // The videos are the cells of the picker's grid, which the system names PXGGridLayout-Info. The picture
        // at the head of the picker is no cell. The wave run puts blue in first, then red.
        let videos = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info")
        let found = videos.firstMatch.waitForExistence(timeout: 40)
        if XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists {
            print("m1-6b-new-project: the system asked a question at picking")
        }
        guard found, videos.count >= 2 else {
            return "fewer than two videos were found in the picker"
        }
        for (place, video) in videos.allElementsBoundByIndex.prefix(3).enumerated() {
            print("m1-6b-new-project: video " + String(place + 1) + " of the picker reads: " + video.label)
        }
        let first = videos.element(boundBy: 0)
        let second = videos.element(boundBy: 1)
        guard first.isHittable, second.isHittable else {
            return "the two videos could not be tapped"
        }
        first.tap()
        second.tap()
        screenshot("m1-6b-new-project-02-picker")

        // The button that confirms is the one on the trailing side of the picker's bar, the right side in English.
        let confirm = app.navigationBars.buttons.allElementsBoundByIndex
            .filter { $0.isEnabled }
            .max { $0.frame.maxX < $1.frame.maxX }
        guard let confirm, confirm.isHittable else {
            return "no button to confirm was found in the picker's bar"
        }
        confirm.tap()

        guard element(app, "editor.root").waitForExistence(timeout: 30) else {
            return "the editor did not open after the button on the trailing side of the bar"
        }
        screenshot("m1-6b-new-project-03-editor")
        // Blue is 3 seconds long and red 4, and a block ends with the length of its clip.
        let firstLength = String(element(app, "editor.clip.1").label.suffix(5))
        let secondLength = String(element(app, "editor.clip.2").label.suffix(5))
        print("m1-6b-new-project: the clips are " + firstLength + " then " + secondLength)
        print("m1-6b-new-project: blue then red is 00:03 then 00:04")
        return nil
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
