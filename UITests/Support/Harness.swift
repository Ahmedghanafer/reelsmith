import XCTest

// The shared helpers of every UI test: start the app, keep a named screenshot, mark the recording.
//
// https://developer.apple.com/documentation/xctest/xcuiapplication/launcharguments
// https://developer.apple.com/documentation/xctest/xctattachment
// https://developer.apple.com/documentation/xctest/xcuiscreen
@MainActor
extension XCTestCase {
    /// Starts the app. `seed` is the name of a seed such as "two-clips", or nil for a start with no seed.
    /// `language` is "en", "ar" or "sv". `playhead` is in ticks, 600 a second.
    func startApp(
        seed: String?, language: String = "en", playhead: Int? = nil, exportFails: Bool = false
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
        app.launchArguments = arguments
        app.launch()
        return app
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
