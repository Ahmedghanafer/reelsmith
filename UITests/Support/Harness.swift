import XCTest

// The shared helpers of every UI test: start the app, keep a named screenshot, mark the recording.
//
// https://developer.apple.com/documentation/xctest/xcuiapplication/launcharguments
// https://developer.apple.com/documentation/xctest/xctattachment
// https://developer.apple.com/documentation/xctest/xcuiscreen
// https://developer.apple.com/documentation/xctest/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xctest/xcuielementattributes/frame
@MainActor
extension XCTestCase {
    /// Starts the app. `seed` is the name of a seed such as "two-clips", or nil for a start with no seed.
    /// `language` is "en", "ar" or "sv". `playhead` is in ticks, 600 a second. `drafts` is "fresh" or "kept".
    func startApp(
        seed: String?, language: String = "en", playhead: Int? = nil, exportFails: Bool = false,
        drafts: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-AppleLanguages", "(" + language + ")", "-AppleLocale", language]
        if let seed {
            arguments += ["-seed", seed]
        }
        if let playhead {
            arguments += ["-playhead", String(playhead)]
        }
        if exportFails {
            arguments.append("-export-fails")
        }
        if let drafts {
            arguments += ["-drafts", drafts]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Waits for the editor after a seeded start, then for the strip to be laid out. The first seeded start
    /// in a fresh simulator writes the clips first, so `editor.root` is expected within 60 seconds and fails
    /// only at 180. A tap on a block is placed from its frame, so the first block is waited for until its
    /// frame has a width and a height, expected within 1 second, failing only above 3. Each wait prints
    /// the seconds it took.
    func waitForTheEditor(_ app: XCUIApplication) {
        let expected: Double = 60
        var started = Date()
        let found = app.descendants(matching: .any)["editor.root"].waitForExistence(timeout: 3 * expected)
        let took = Date().timeIntervalSince(started)
        print("m1-18-held-runner: editor.root after \(took) seconds, expected \(expected), limit \(3 * expected)")
        XCTAssertTrue(found, "editor.root did not come within \(3 * expected) seconds of the start")
        guard found else {
            return
        }
        // The text of a seed start names the count of the clips first, in the digits 0 to 9 in every language.
        let info = app.staticTexts["editor.seedInfo"].label
        if info.first(where: { $0.isNumber }) == Character("0") {
            print("m1-18-held-runner: no block is waited for, the project has no clip")
            return
        }
        let block = app.descendants(matching: .any)["editor.clip.1"]
        started = Date()
        var laidOut = block.exists && block.frame.width > 0 && block.frame.height > 0
        var waited = Date().timeIntervalSince(started)
        // The limit counts from the end of the first read, so a slow first read still gets a second one.
        let first = waited
        while !laidOut && waited <= first + 3 {
            Thread.sleep(forTimeInterval: 0.2)
            laidOut = block.exists && block.frame.width > 0 && block.frame.height > 0
            waited = Date().timeIntervalSince(started)
        }
        print("m1-18-held-runner: waited \(waited) seconds for the frame of editor.clip.1, expected 1, limit 3")
        XCTAssertTrue(laidOut, "editor.clip.1 had no frame within 3 seconds of the editor")
    }

    /// Keeps a screenshot of the screen under the name, also when the test passes.
    func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Marks the start of a named stretch of the recording: a text attachment `<name>.mark.txt`
    /// that holds the clock second of the call, whole seconds since 1970.
    func mark(_ name: String) {
        let attachment = XCTAttachment(string: String(Int(Date().timeIntervalSince1970)))
        attachment.name = name + ".mark.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
