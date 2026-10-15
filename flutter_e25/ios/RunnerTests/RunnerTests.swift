import XCTest

/// Appends one line, with the seconds since the first line, to ui-lines.txt in the folder the run names in
/// E25_OUT (passed as TEST_RUNNER_E25_OUT), since the prints of a UI test do not reach the xcodebuild output.
private let e25Start = Date()
func e25Line(_ line: String) {
    let text = String(format: "%.1f s ", Date().timeIntervalSince(e25Start)) + line + "\n"
    print(text, terminator: "")
    guard let folder = ProcessInfo.processInfo.environment["E25_OUT"] else { return }
    let url = URL(fileURLWithPath: folder).appendingPathComponent("ui-lines.txt")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(text.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? text.data(using: .utf8)!.write(to: url)
    }
}

/// XCUITest against the Flutter build: identifiers from Semantics, a launch argument, selected state,
/// a slider and a right to left launch. Each check prints one line "E25 UI <check>: <result>".
final class RunnerTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func say(_ line: String) {
        e25Line("E25 UI \(line)")
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
        say("tapping play")
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
        say("sliders count: \(app.sliders.count) adjustable count: \(app.descendants(matching: .any).matching(NSPredicate(format: "value ENDSWITH '%'")).count)")
        let valued = app.descendants(matching: .any).matching(NSPredicate(format: "value ENDSWITH '%'")).firstMatch
        say("slider value element type: \(valued.elementType.rawValue) value: \(String(describing: valued.value))")
        if app.sliders.count > 0 {
            app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.75)
            say("adjust on app.sliders done")
        } else {
            valued.swipeRight()
            say("no slider kind, swiped right on the value element")
        }
        Thread.sleep(forTimeInterval: 1.5)
        say("slider after: value \(String(describing: valued.value)) text: \(element(app, "e25.sliderValue").label)")
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

/// Probes of XCUITest against Flutter widgets: values, typing, gestures, the system picker, frames,
/// alerts and queries by kind. Launched with -probe. Each probe prints "E25 PROBE <n> <what>: <result>".
final class ProbeTests: XCTestCase {
    private func say(_ line: String) {
        e25Line("E25 PROBE \(line)")
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

    func testProbes() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-probe"]
        app.launch()
        let first = element(app, "p.value")
        say("0 probe screen: \(first.waitForExistence(timeout: 60))")

        // 1: the value of an element that is not a slider.
        say("1 value: \(String(describing: first.value)) label: \(first.label) type: \(first.elementType.rawValue)")

        // 7: queries by kind.
        let kinds: [(String, XCUIElementQuery, String)] = [
            ("buttons", app.buttons, "p.pick"), ("buttons", app.buttons, "p.alert"),
            ("staticTexts", app.staticTexts, "p.echo"), ("sliders", app.sliders, "p.slider"),
            ("textFields", app.textFields, "p.field"), ("otherElements", app.otherElements, "p.region"),
            ("otherElements", app.otherElements, "p.pick"), ("any", app.descendants(matching: .any), "p.field"),
            ("any", app.descendants(matching: .any), "p.slider"),
        ]
        for (kind, query, id) in kinds {
            let found = query[id]
            say("7 \(kind)[\(id)]: \(found.exists ? "found, type \(found.elementType.rawValue)" : "not found")")
        }
        say("7 counts: textFields \(app.textFields.count) sliders \(app.sliders.count) buttons \(app.buttons.count)")

        // 2: typing into a TextField found by identifier.
        var field = app.textFields["p.field"]
        if !field.exists {
            field = element(app, "p.field")
        }
        field.tap()
        field.typeText("hello e25")
        Thread.sleep(forTimeInterval: 1)
        say("2 typed, field value: \(String(describing: field.value)) echo: \(element(app, "p.echo").label)")
        first.tap()

        // 3: pinch and rotate on a GestureDetector.
        let area = element(app, "p.gestureArea")
        area.pinch(withScale: 2, velocity: 1)
        Thread.sleep(forTimeInterval: 1)
        say("3 after pinch: \(element(app, "p.gesture").label)")
        area.rotate(0.8, withVelocity: 1)
        Thread.sleep(forTimeInterval: 1)
        say("3 after rotate: \(element(app, "p.gesture").label)")

        // 5: the frame of a region against its laid out size.
        say("5 frame: \(element(app, "p.region").frame) laid out: \(element(app, "p.regionSize").label)")

        // 6: an AlertDialog through app.alerts.
        element(app, "p.alert").tap()
        Thread.sleep(forTimeInterval: 1.5)
        say("6 alerts count: \(app.alerts.count) ok by id: \(element(app, "p.alertOk").exists)")
        shot("probe-alert")
        if app.alerts.count > 0 {
            app.alerts.firstMatch.buttons.firstMatch.tap()
            say("6 tapped through app.alerts")
        } else {
            element(app, "p.alertOk").tap()
            say("6 tapped by identifier p.alertOk")
        }
        Thread.sleep(forTimeInterval: 1)
        say("6 result: \(element(app, "p.alertResult").label)")

        // 4: the system photo picker over the Flutter app.
        element(app, "p.pick").tap()
        let failure = chooseInThePhotoPicker(app, fromTheEnd: 1)
        say("4 picker steps: \(failure ?? "all done")")
        let picked = element(app, "p.picked")
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline && picked.label.hasPrefix("nothing") {
            Thread.sleep(forTimeInterval: 0.5)
        }
        say("4 picked: \(picked.label)")
        shot("probe-end")
    }

    // The way of UITests/Support/Picker.swift, cut down to one cell: the grid's cells by the system's
    // identifier, tapped by coordinate, then the control furthest right in the picker's bar.
    private func chooseInThePhotoPicker(_ app: XCUIApplication, fromTheEnd place: Int) -> String? {
        let cells = app.scrollViews.images.matching(identifier: "PXGGridLayout-Info")
        guard cells.firstMatch.waitForExistence(timeout: 40) else {
            return "no cell of the picker's grid came within 40 seconds"
        }
        Thread.sleep(forTimeInterval: 2)
        guard let before = try? app.snapshot() else {
            return "no snapshot of the grid"
        }
        var grid: [any XCUIElementSnapshot] = []
        for view in flattened(before) where view.elementType == .scrollView {
            let found = flattened(view).filter { $0.elementType == .image && $0.identifier == "PXGGridLayout-Info" }
            if found.count > grid.count {
                grid = found
            }
        }
        e25Line("picker: the grid holds \(grid.count) cells")
        guard grid.count >= place else {
            return "the grid held \(grid.count) cells"
        }
        let frame = grid[grid.count - place].frame
        let top = min(grid[0].frame.minY, frame.minY)
        tap(app, theMiddleOf: frame)
        Thread.sleep(forTimeInterval: 2)
        shot("probe-picker")
        guard let tree = try? app.snapshot() else {
            return "no snapshot of the picker"
        }
        let all = flattened(tree).filter { !$0.identifier.hasPrefix("p.") && $0.frame.width > 1 }
        guard let bar = all.filter({ $0.elementType == .button && $0.frame.midY < top })
            .min(by: { $0.frame.minY < $1.frame.minY })
        else {
            return nil
        }
        let row = all.filter { abs($0.frame.midY - bar.frame.midY) <= 24 && $0.frame.width <= 120 }
        guard let confirm = row.filter({ $0.frame.midX > tree.frame.width * 2 / 3 })
            .max(by: { $0.frame.maxX < $1.frame.maxX })
        else {
            return "no element on the right of the picker's bar"
        }
        e25Line("picker: tapped to confirm, kind \(confirm.elementType.rawValue) at \(confirm.frame): \(confirm.label)")
        tap(app, theMiddleOf: confirm.frame)
        return nil
    }

    private func flattened(_ node: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        var all: [any XCUIElementSnapshot] = [node]
        for child in node.children {
            all += flattened(child)
        }
        return all
    }

    private func tap(_ app: XCUIApplication, theMiddleOf frame: CGRect) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .tap()
    }
}
