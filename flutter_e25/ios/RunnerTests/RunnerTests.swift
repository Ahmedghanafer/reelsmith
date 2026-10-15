import XCTest

/// XCUITest against the Flutter build: identifiers from Semantics, a launch argument, selected state,
/// a slider and a right to left launch. Each check prints one line "E25 UI <check>: <result>".
final class RunnerTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func say(_ line: String) {
        print("E25 UI \(line)")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testIdentifiersPlaySeedSelectedSlider() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-seed", "e25"]
        let start = Date()
        app.launch()

        let play = element(app, "e25.play")
        say("play found: \(play.waitForExistence(timeout: 60)) after \(Int(Date().timeIntervalSince(start))) s, type \(play.elementType.rawValue)")
        let frames = element(app, "e25.frames")
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline && (frames.label.hasPrefix("frames 0") || !frames.exists) {
            Thread.sleep(forTimeInterval: 0.5)
        }
        say("frames label: \(frames.label)")

        let seed = element(app, "e25.seed")
        say("seed found: \(seed.waitForExistence(timeout: 10)) label: \(seed.label)")
        XCTAssertEqual(seed.label, "seed e25")

        let time = element(app, "e25.time")
        let before = time.label
        play.tap()
        Thread.sleep(forTimeInterval: 2.5)
        let after = time.label
        say("time before: \(before) after: \(after) changed: \(before != after)")
        XCTAssertNotEqual(before, after)
        shot("ui-1-playing")

        let selected = element(app, "e25.selected")
        say("selected found: \(selected.exists) isSelected: \(selected.isSelected) label: \(selected.label)")

        let sliderById = element(app, "e25.slider")
        say("slider by id type: \(sliderById.elementType.rawValue) value: \(String(describing: sliderById.value))")
        let slider = app.sliders.firstMatch
        say("sliders count: \(app.sliders.count) first value: \(String(describing: slider.value)) identifier: \(slider.identifier)")
        if slider.exists {
            slider.adjust(toNormalizedSliderPosition: 0.75)
            Thread.sleep(forTimeInterval: 1.5)
            say("slider after adjust value: \(String(describing: slider.value)) text: \(element(app, "e25.sliderValue").label)")
        }
        shot("ui-2-slider")
        app.terminate()
    }

    func testArabicLaunchIsRightToLeft() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ar)", "-AppleLocale", "ar"]
        app.launch()
        let dir = element(app, "e25.dir")
        say("dir found: \(dir.waitForExistence(timeout: 60)) label: \(dir.label)")
        shot("ui-3-arabic")
        XCTAssertTrue(dir.label.hasPrefix("dir rtl"))
        app.terminate()
    }
}
