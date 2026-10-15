import XCTest

// The whole path of clips in one test, as she walks it: a new project on the landscape canvas from the system picker
// (blue, red and the test photo), blue added once more, a pinch inward, the photo moved first by a press and drag,
// a cut of blue, red raised to 200 percent, undo and redo, music from a video, the fold of the frames, the volume of
// the clips dragged while the video plays, an export at 1080p and 30, and the draft reopened with all of it. Then the
// framing on `two-clips` (the 9:16 canvas): fit, fill, blurred bars for all clips and the Instagram guide, and punch
// in on `two-clips-wide`, where a scripted pinch on the picture is taken (D-104). A clip is read through the value of
// its block, "<media> <start>+<duration> <volume times 100> <v or p>", its frames through `editor.frames.<n>`,
// "<tiles> <drawn> <made>", its framing through `clip.frameInfo`, "<fit|fill> <black|blur> <zoom times 100>
// <x times 1000>,<y times 1000>", the sound through `editor.soundInfo`, a draft through `start.draftsInfo`. No picture
// is judged by a pixel. When the picker is not driven the walk goes on from the seed photo-wide (blue, the photo, red)
// and leaves out every pick, the music of a video among them. That the lifted photo follows the finger is read by the
// QA pass in the recording from the mark `clip-path-02-lift`.
//
// https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/terminate()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap()
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/pinch(withscale:velocity:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:)
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:withvelocity:thenholdforduration:)
// https://developer.apple.com/documentation/xcuiautomation/xcuigesturevelocity
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/withoffset(_:)
// https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/screenpoint
// https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/frame
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isenabled
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/isselected
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/label
// https://developer.apple.com/documentation/xcuiautomation/xcuielementattributes/value
// https://developer.apple.com/documentation/foundation/thread/sleep(fortimeinterval:)
@MainActor
final class WholeClipPathTests: XCTestCase {
    /// The seconds from the tap on the right of the picker's bar to the clips in the editor: a copy and the still
    /// movie of a photo.
    private let expectedCopy = 20.0

    /// The seconds from a launch to the start screen.
    private let expectedStart = 20.0

    /// The seconds from the tap on `editor.projects` to the start screen, the cover written on the way.
    private let expectedBack = 5.0

    /// The export at 1080p and 30 with its save, in seconds, as the first export of a run is.
    private let expectedExport = 45.0

    /// The seconds from the end of the pick to the music in the project: the copy of a video of 3 seconds.
    private let expectedImport = 10.0

    /// The seconds for the frames of every block to come: the criterion's 10 seconds are three times it.
    private let expectedFrames = 10.0 / 3

    /// The seconds for a press and drag to land: the move is sent when she lets go, after the hold.
    private let expectedMove = 10.0 / 3

    /// The most drags of a slider toward its end before the value must read it.
    private let mostMoves = 5

    /// Half the width of the thumb: the track runs from this far inside one end of the slider to as far inside the
    /// other.
    private let thumbHalf: CGFloat = 14

    /// The framing a clip has before any framing action.
    private let standard = "fit black 100 0,0"

    /// The start of the walk and of its step, for the printed times.
    private var walkBegan = Date()
    private var stepBegan = Date()

    func testTheWholePathOfClipsFromANewProjectWithAPhotoToAReopenedDraft() {
        mark("clip-path-01-path")
        walkBegan = Date()
        stepBegan = walkBegan

        // A new project from the picker, on a folder of drafts emptied by the launch.
        var app = startApp(seed: nil, drafts: "fresh")
        XCTAssertEqual(draftsInfo(app), "0")
        let stopped = driveThePicks(app)
        if let stopped {
            print("clip-path: picker not driven: \(stopped). The walk goes on from -drafts fresh -seed photo-wide and skips the picks")
            app.terminate()
            app = startApp(seed: "photo-wide", drafts: "fresh")
            waitForTheEditor(app)
            waitUntil("3 clips, 3 files in editor.seedInfo on photo-wide") {
                app.staticTexts["editor.seedInfo"].label == "3 clips, 3 files"
            }
        } else {
            print("clip-path: picker driven")
        }
        let driven = stopped == nil
        // Blue, red, the photo and blue again when driven. Blue, the photo and red on photo-wide.
        let count = driven ? 4 : 3
        let photo = driven ? 3 : 2
        stepDone("the new project and the added clip")

        // The frames of every block, blue picked twice being two media.
        waitUntil("every editor.frames.<n> with all its tiles drawn and made \(count)", expected: expectedFrames) {
            (1...count).allSatisfy { position in
                let fields = self.value(app, "editor.frames." + String(position)).split(separator: " ")
                return fields.count == 3 && fields[0] != "0" && fields[0] == fields[1] && fields[2] == Substring(String(count))
            }
        }
        for position in 1...count {
            print("clip-path: editor.frames.\(position) reads " + value(app, "editor.frames." + String(position)))
        }
        stepDone("the frames")

        // A pinch inward, then the strip scrubbed to 5 seconds. Blue is 3 seconds long, so its width gives the scale.
        let first = element(app, "editor.clip.1")
        let wide = first.frame.width
        print("clip-path: the pinch with scale 0.5 at the playhead " + playhead(app))
        element(app, "editor.timelineRegion").pinch(withScale: 0.5, velocity: -1)
        waitUntil("editor.clip.1 narrower than \(wide) after a pinch with scale 0.5") { first.frame.width < wide - 1 }
        print("clip-path: editor.clip.1 is \(first.frame.width) points wide after the pinch, \(wide) before it")
        scrub(app, "the playhead reading 00:05", toX: {
            first.frame.minX + first.frame.width / 3 * 5.5
        }) {
            self.playhead(app) == "00:05"
        }
        stepDone("the pinch and the scrub")

        // The photo pressed at its middle, dragged to the left end of the first block and held there: it goes first.
        let lifted = element(app, "editor.clip." + String(photo))
        let photoValue = value(app, "editor.clip." + String(photo))
        print("clip-path: the photo editor.clip.\(photo) reads \(photoValue) at \(lifted.frame), hittable \(lifted.isHittable), editor.clip.1 at \(first.frame)")
        XCTAssertTrue(photoValue.hasSuffix(" p"), "the photo before the press: " + photoValue)
        let screen = element(app, "editor.timelineRegion").frame
        XCTAssertTrue(screen.contains(CGPoint(x: lifted.frame.midX, y: lifted.frame.midY)), "the middle of the photo on the screen")
        XCTAssertTrue(first.frame.minX >= screen.minX && first.frame.minX < screen.maxX, "the left end of editor.clip.1 on the screen")
        let before = playhead(app)
        let from = lifted.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = first.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 4, dy: 0))
        print("clip-path: the press of the photo at the playhead " + before + ", from \(from.screenPoint) to \(to.screenPoint)")
        mark("clip-path-02-lift")
        from.press(forDuration: 0.6, thenDragTo: to, withVelocity: XCUIGestureVelocity(rawValue: 200), thenHoldForDuration: 1)
        waitUntil("editor.clip.1 ending 0+1800 100 p after the press and drag", expected: expectedMove) {
            self.value(app, "editor.clip.1").hasSuffix("0+1800 100 p")
        }
        print("clip-path: after the press and drag the blocks read \(values(app, count)), the playhead " + playhead(app))
        XCTAssertEqual(playhead(app), before, "the playhead after the move")
        stepDone("the move of the photo")

        // Blue, now second, cut before the playhead in its middle.
        let blue = element(app, "editor.clip.2")
        scrub(app, "the playhead inside editor.clip.2 with half a second on both sides", toX: { blue.frame.midX }) {
            let line = self.element(app, "editor.playhead").frame.midX
            let half = blue.frame.width / 3 / 2
            return line - blue.frame.minX > half && blue.frame.maxX - line > half
        }
        select(app, "editor.clip.2")
        tapOn(app, "clip.cutBefore")
        waitUntil("a source start above 0 in the value of editor.clip.2 after clip.cutBefore") {
            self.sourceStart(self.value(app, "editor.clip.2")) > 0
        }
        print("clip-path: after clip.cutBefore editor.clip.2 reads " + value(app, "editor.clip.2") + ", the playhead " + playhead(app))
        stepDone("the cut of blue")

        // Red, now third, raised to its highest, then undo and redo.
        let red = element(app, "editor.clip.3")
        scrub(app, "the middle of editor.clip.3 on the screen and hittable", toX: { red.frame.midX }) {
            red.isHittable && screen.minX + 10 < red.frame.midX && red.frame.midX < screen.maxX - 10
        }
        select(app, "editor.clip.3")
        raiseRed(app)
        tapOn(app, "editor.undo")
        waitUntil("editor.clip.3 ending 100 v after one undo") { self.value(app, "editor.clip.3").hasSuffix(" 100 v") }
        print("clip-path: after one undo editor.clip.3 reads " + value(app, "editor.clip.3"))
        tapOn(app, "editor.redo")
        waitUntil("editor.clip.3 ending 200 v after the redo") { self.value(app, "editor.clip.3").hasSuffix(" 200 v") }
        print("clip-path: after the redo editor.clip.3 reads " + value(app, "editor.clip.3"))
        stepDone("the volume of red")

        // The music from a video, as the walk of m3-9 takes it, then done: its bar on the strip.
        var music = false
        if driven {
            tapOn(app, "editor.sound")
            let video = element(app, "sound.addFromVideo")
            waitUntil("sound.addFromVideo after the tap on editor.sound") { video.exists }
            tapOn(app, "sound.addFromVideo")
            if let stoppedMusic = chooseInThePhotoPicker(app, fromTheEnd: [1], confirms: false, picture: nil) {
                // The draft is written after every edit, so the walk goes on from it without music.
                print("clip-path: picker not driven for the music: \(stoppedMusic). The walk goes on from the kept draft without music")
                app.terminate()
                app = openTheDraft(language: "en")
            } else {
                waitUntil("0+1800 in field 3 of editor.soundInfo after the pick", expected: expectedImport) {
                    self.field(app, 3) == "0+1800" && !self.element(app, "sound.importWords").exists
                }
                print("clip-path: after the pick editor.soundInfo reads " + soundInfo(app))
                tapOn(app, "sound.done")
                waitUntil("editor.music on the strip after sound.done") {
                    !self.element(app, "editor.soundRegion").exists && self.element(app, "editor.music").exists
                }
                music = true
            }
        } else {
            print("clip-path: the pick of the music from a video skipped, the picker is not driven")
        }
        screenshot("clip-path-01-strip")
        stepDone("the music")

        // The fold and back. The strip of 128 points with the music row folds to 96.
        let region = element(app, "editor.timelineRegion")
        let photoBlock = element(app, "editor.clip.1")
        tapOn(app, "editor.frames")
        waitUntil("editor.clip.1 24 high and the strip 96 after the tap on editor.frames") {
            abs(photoBlock.frame.height - 24) <= 1 && abs(region.frame.height - 96) <= 1
        }
        print("clip-path: folded the strip is \(region.frame.height) high, editor.clip.1 \(photoBlock.frame.height)")
        XCTAssertEqual(region.frame.height, 96, accuracy: 1)
        if music {
            let musicY = element(app, "editor.music").frame.minY - region.frame.minY
            print("clip-path: folded editor.music at y \(musicY) of the strip")
            XCTAssertEqual(musicY, 68, accuracy: 1)
        }
        tapOn(app, "editor.frames")
        waitUntil("a strip 128 high with editor.clip.1 56 high after the second tap on editor.frames") {
            abs(region.frame.height - 128) <= 1 && abs(photoBlock.frame.height - 56) <= 1
        }
        print("clip-path: unfolded the strip is \(region.frame.height) high, editor.clip.1 \(photoBlock.frame.height)")
        stepDone("the fold")

        // The volume of the clips dragged to its lowest while the video plays, from the start of the project.
        scrub(app, "the playhead reading 00:00", toX: { photoBlock.frame.minX }) { self.playhead(app) == "00:00" }
        tapOn(app, "editor.sound")
        let clipsPart = element(app, "sound.tab.clips")
        waitUntil("sound.tab.clips after the tap on editor.sound") { clipsPart.exists }
        tapOn(app, "sound.tab.clips")
        let slider = app.sliders["sound.clipVolume"]
        waitUntil("the slider sound.clipVolume after the tap on sound.tab.clips") { slider.exists }
        let play = element(app, "editor.play")
        // The volume of the clips is 1: the thumb stands at the higher end. Placed before the play.
        let left = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let thumb = left.withOffset(CGVector(dx: slider.frame.width - thumbHalf, dy: 0))
        let lowest = left.withOffset(CGVector(dx: -30, dy: 0))
        print("clip-path: the slider sound.clipVolume at \(slider.frame), the thumb at \(thumb.screenPoint), the drag to \(lowest.screenPoint)")
        tapOn(app, "editor.play")
        waitUntil("editor.play labelled Pause after the tap on it") { play.label == "Pause" }
        waitUntil("the time past 00:00 after the tap on editor.play", expected: 2) { self.time(app) != "00:00" }
        print("clip-path: the drag of sound.clipVolume at the playhead " + playhead(app))
        mark("clip-path-03-plays")
        thumb.press(forDuration: 0.1, thenDragTo: lowest, withVelocity: XCUIGestureVelocity(rawValue: 400), thenHoldForDuration: 0)
        waitUntil("editor.soundInfo beginning 0 . after the drag") { self.soundInfo(app).hasPrefix("0 .") }
        let once = time(app)
        // The time is read again one second on: the second is the span of the read, not a wait for an effect.
        Thread.sleep(forTimeInterval: 1)
        let later = time(app)
        print("clip-path: after the drag the time read \(once), one second on \(later), editor.play \(play.label), editor.soundInfo \(soundInfo(app))")
        XCTAssertGreaterThan(later, once, "the time one second after the drag")
        XCTAssertEqual(play.label, "Pause", "editor.play after the drag")
        XCTAssertTrue(soundInfo(app).hasPrefix("0 ."), soundInfo(app))
        tapOn(app, "editor.undo")
        waitUntil("editor.soundInfo beginning 100 . after one undo") { self.soundInfo(app).hasPrefix("100 .") }
        print("clip-path: after one undo editor.soundInfo reads " + soundInfo(app))
        tapOn(app, "sound.done")
        waitUntil("no editor.soundRegion after sound.done") { !self.element(app, "editor.soundRegion").exists }
        stepDone("the volume of the clips while playing")

        // The export at 1080p and 30, the choice of a new project.
        let done = element(app, "export.done")
        let close = element(app, "export.close")
        let began = Date()
        tapOn(app, "editor.export")
        waitUntil("the saved panel after the tap on editor.export", expected: expectedExport) { done.exists || close.exists }
        print("clip-path: the export at 1080p and 30 took \(Date().timeIntervalSince(began)) seconds, expected \(expectedExport), limit \(3 * expectedExport)")
        if close.exists {
            let words = element(app, "export.words")
            print("clip-path: the export failed, export.words reads " + (words.exists ? words.label : "nothing"))
        }
        XCTAssertTrue(done.exists, "the saved panel")
        if done.exists {
            XCTAssertEqual(element(app, "export.fileInfo").label, "1920 1080 30")
        }
        screenshot("clip-path-02-saved")
        let panel = done.exists ? "export.done" : "export.close"
        if element(app, panel).exists {
            tapOn(app, panel)
            waitUntil("the panel gone after the tap on " + panel) { !self.element(app, panel).exists }
        }
        stepDone("the export")

        // Back, the app ended, and the draft reopened with all of it.
        tapOn(app, "editor.projects")
        waitUntil("start.newProject after the tap on editor.projects", expected: expectedBack) {
            self.element(app, "start.newProject").exists
        }
        app.terminate()
        app = openTheDraft(language: "en", info: "1 " + String(count) + "+")
        waitUntil("the photo first and red at 200 in the reopened draft") {
            self.value(app, "editor.clip.1").hasSuffix("0+1800 100 p") && self.value(app, "editor.clip.3").hasSuffix(" 200 v")
        }
        print("clip-path: the reopened draft reads \(values(app, count))")
        XCTAssertTrue(element(app, "editor.undo").isEnabled, "the history did not come back with the draft")
        let reopened = element(app, "editor.timelineRegion")
        print("clip-path: in the reopened draft the strip is \(reopened.frame.height) high, editor.clip.1 \(element(app, "editor.clip.1").frame.height)")
        XCTAssertEqual(reopened.frame.height, 128, accuracy: 1, "the strip unfolded")
        XCTAssertEqual(element(app, "editor.clip.1").frame.height, 56, accuracy: 1, "the blocks unfolded")
        XCTAssertTrue(element(app, "editor.frames.1").exists, "the frames of editor.clip.1")
        app.terminate()

        // The strip of the walk in Arabic and in Swedish, from the same draft.
        for language in ["ar", "sv"] {
            app = openTheDraft(language: language)
            waitUntil("the photo first in the reopened draft in " + language) {
                self.value(app, "editor.clip.1").hasSuffix("0+1800 100 p")
            }
            screenshot("clip-path-01-strip-" + language)
            app.terminate()
        }
        stepDone("the reopened draft")

        // Framing on the 9:16 canvas: blue between bars, then red. At 1 second blue is from x 141 to 321.
        app = startApp(seed: "two-clips", playhead: 600, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.1")
        waitUntil("clip.frameInfo reading " + standard) { self.info(app) == self.standard }
        frame(app, "clip.fill", "fill black 100 0,0")
        frame(app, "clip.fit", standard)
        frame(app, "clip.blur", "fit blur 100 0,0")
        tapOn(app, "clip.applyAll")
        let second = element(app, "editor.clip.2")
        print("clip-path: the tap on editor.clip.2 at the playhead " + playhead(app))
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        waitUntil("editor.clip.2 selected and clip.frameInfo reading fit blur 100 0,0 after clip.applyAll") {
            second.isSelected && self.info(app) == "fit blur 100 0,0"
        }
        print("clip-path: with red selected clip.frameInfo reads " + info(app))
        stepDone("the framing")

        // The guide over the picture, then gone.
        tapOn(app, "clip.guide")
        waitUntil("editor.guide over the picture after clip.guide") {
            self.element(app, "editor.guide").exists && self.element(app, "editor.guide.safe").exists
                && self.element(app, "editor.guide.safe").frame.width > 0
        }
        print("clip-path: editor.guide.safe at \(element(app, "editor.guide.safe").frame), editor.picture at \(element(app, "editor.picture").frame)")
        tapOn(app, "clip.guide")
        waitUntil("no editor.guide after clip.guide again") { !self.element(app, "editor.guide").exists }
        screenshot("clip-path-03-framed")
        app.terminate()
        for language in ["ar", "sv"] {
            app = startApp(seed: "two-clips", language: language, playhead: 600, drafts: "fresh")
            waitForTheEditor(app)
            select(app, "editor.clip.1")
            frame(app, "clip.blur", "fit blur 100 0,0")
            screenshot("clip-path-03-framed-" + language)
            app.terminate()
        }
        stepDone("the guide")

        // Punch in on the 16:9 canvas, where a scripted pinch on the picture is taken (D-104). At 4 seconds red is
        // from x 141 to 381, 1080 by 1920 between bars.
        app = startApp(seed: "two-clips-wide", playhead: 2400, drafts: "fresh")
        waitForTheEditor(app)
        select(app, "editor.clip.2")
        waitUntil("clip.frameInfo reading " + standard) { self.info(app) == self.standard }
        let picture = element(app, "editor.picture")
        pinch(picture, app)
        let pinched = info(app)
        print("clip-path: the drag on the picture at the playhead " + playhead(app))
        let start = picture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -60)))
        waitUntil("an offset other than the one of the pinch after a drag of 60 points upward") {
            self.info(app) != pinched && self.zoom(app) == self.zoom(of: pinched)
        }
        print("clip-path: after the drag clip.frameInfo reads " + info(app))
        undo(app, to: pinched)
        undo(app, to: standard)
        frame(app, "clip.blur", "fit blur 100 0,0")
        pinch(picture, app)
        undo(app, to: "fit blur 100 0,0")
        stepDone("punch in")

        // A run in which this line is missing did not walk, whatever its result says.
        let seconds = Int(Date().timeIntervalSince(walkBegan))
        let picker = driven ? "picker driven" : "picker not driven, from the seed photo-wide"
        print("clip-path: walk finished, \(picker), music \(music ? "from a video" : "none"), \(seconds) seconds")
    }

    /// Taps `start.newProject`, picks blue, red and the photo, then `editor.addClips` and blue once more, and reads
    /// three blocks and then four. Nil when all of it was done, else the step of the picker that found nothing.
    private func driveThePicks(_ app: XCUIApplication) -> String? {
        XCTAssertTrue(element(app, "start.landscape").isSelected, "the landscape shape")
        tapOn(app, "start.newProject")
        if let stopped = chooseInThePhotoPicker(app, fromTheEnd: [1, 2, 3], confirms: true, picture: nil, photos: true) {
            return stopped
        }
        let began = Date()
        let opened = element(app, "editor.root").waitForExistence(timeout: 3 * expectedCopy)
        print("clip-path: waited \(Date().timeIntervalSince(began)) seconds for editor.root after the picker, expected \(expectedCopy), limit \(3 * expectedCopy)")
        // A pick that was confirmed and opens no editor is a fault of the product, not of the picker: the test fails,
        // and the walk still goes on from the seed.
        XCTAssertTrue(opened, "editor.root after the confirmed pick")
        guard opened else {
            return "the editor did not open within \(3 * expectedCopy) seconds of the tap on the right of the picker's bar"
        }
        waitForTheEditor(app)
        waitUntil("3 clips, 3 files in editor.seedInfo") { app.staticTexts["editor.seedInfo"].label == "3 clips, 3 files" }
        print("clip-path: the new project reads \(values(app, 3))")
        XCTAssertTrue(value(app, "editor.clip.3").hasSuffix("0+1800 100 p"), value(app, "editor.clip.3"))
        XCTAssertFalse(element(app, "editor.clip.4").exists)

        tapOn(app, "editor.addClips")
        if let stopped = chooseInThePhotoPicker(app, fromTheEnd: [1], confirms: true, picture: nil, photos: true) {
            return stopped
        }
        waitUntil("4 clips, 4 files in editor.seedInfo after the picker", expected: expectedCopy) {
            app.staticTexts["editor.seedInfo"].label == "4 clips, 4 files"
        }
        // A confirmed pick that adds no clip has failed above, and the walk goes on from the seed.
        guard app.staticTexts["editor.seedInfo"].label == "4 clips, 4 files" else {
            return "the added clip did not come within \(3 * expectedCopy) seconds of the tap on the right of the picker's bar"
        }
        print("clip-path: after the added clip the blocks read \(values(app, 4))")
        XCTAssertTrue(element(app, "editor.clip.4").exists)
        XCTAssertFalse(element(app, "editor.clip.5").exists)
        return nil
    }

    /// Starts the app with `-drafts kept` in the language, reads the line of the drafts, which begins with `info`
    /// when one is named, and opens `drafts.row.1`.
    private func openTheDraft(language: String, info: String? = nil) -> XCUIApplication {
        let app = startApp(seed: nil, language: language, drafts: "kept")
        let line = draftsInfo(app)
        if let info {
            XCTAssertTrue(line.hasPrefix(info), line)
        }
        waitUntil("drafts.row.1 on the start screen", expected: expectedBack) { self.element(app, "drafts.row.1").exists }
        tapOn(app, "drafts.row.1")
        waitForTheEditor(app)
        return app
    }

    /// Drags the strip from the middle of its text row (y 84, no text in the walk) until the condition holds, at most
    /// four drags, each bringing the x that `target` reads to the playhead line. The text row holds no trim handle,
    /// so a drag that begins near the edge of the screen never trims the selected clip. The pan of the strip begins
    /// after about 10 points, which its translation leaves out, so each drag is 10 points longer. A drag is held to
    /// 340 points to stay on the screen.
    private func scrub(_ app: XCUIApplication, _ what: String, toX target: () -> CGFloat, until reached: () -> Bool) {
        let region = element(app, "editor.timelineRegion")
        let line = element(app, "editor.playhead")
        var drags = 0
        while !reached() && drags < 4 {
            var distance = line.frame.midX - target()
            distance += distance < 0 ? -10 : 10
            distance = max(-340, min(340, distance))
            let x = distance < 0 ? region.frame.maxX - 20 : region.frame.minX + 20
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: x, dy: region.frame.minY + 84))
            print("clip-path: a scrub of \(distance) points from x \(x) at the playhead " + playhead(app))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: distance, dy: 0)))
            drags += 1
        }
        waitUntil(what + " after \(drags) scrubs", reached)
        print("clip-path: after \(drags) scrubs the playhead reads " + playhead(app))
    }

    /// Prints the playhead where the tap is made, then taps the element.
    private func tapOn(_ app: XCUIApplication, _ identifier: String) {
        print("clip-path: the tap on \(identifier) at the playhead \(playhead(app))")
        element(app, identifier).tap()
    }

    /// Taps the middle of the block and waits until it is selected and the clip panel shows.
    private func select(_ app: XCUIApplication, _ identifier: String) {
        let block = element(app, identifier)
        print("clip-path: the tap on " + identifier + " at the playhead " + playhead(app))
        block.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil(identifier + " selected and editor.clipRegion after the tap on it") {
            block.isSelected && self.element(app, "editor.clipRegion").exists
        }
    }

    /// Drags the thumb of `clip.volume` past its higher end, as `ClipGainTests` does, until red reads 200.
    private func raiseRed(_ app: XCUIApplication) {
        let slider = app.sliders["clip.volume"]
        waitUntil("the slider clip.volume") { slider.exists }
        let width = slider.frame.width
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let highest = start.withOffset(CGVector(dx: width + 30, dy: 0))
        var moves = 0
        while !value(app, "editor.clip.3").hasSuffix(" 200 v") && moves < mostMoves {
            let before = value(app, "editor.clip.3")
            let fields = before.split(separator: " ")
            let share = CGFloat(max(fields.count > 2 ? Int(fields[2]) ?? 0 : 0, 0)) / 200
            let thumb = start.withOffset(CGVector(dx: thumbHalf + (width - 2 * thumbHalf) * share, dy: 0))
            print("clip-path: drag \(moves + 1) of clip.volume from \(thumb.screenPoint) at the playhead " + playhead(app))
            thumb.press(forDuration: 0.05, thenDragTo: highest)
            moves += 1
            // A drag that misses the thumb changes nothing, so this wait does not fail: the assert on " 200 v" decides.
            waitUntil("a value of editor.clip.3 other than " + before + " after drag \(moves)", failing: false) {
                self.value(app, "editor.clip.3") != before
            }
            print("clip-path: after drag \(moves) editor.clip.3 reads " + value(app, "editor.clip.3"))
        }
        XCTAssertTrue(value(app, "editor.clip.3").hasSuffix(" 200 v"), value(app, "editor.clip.3"))
    }

    /// Taps a control of the framing row and waits until `clip.frameInfo` reads the line.
    private func frame(_ app: XCUIApplication, _ control: String, _ line: String) {
        tapOn(app, control)
        waitUntil("clip.frameInfo reading " + line + " after " + control) { self.info(app) == line }
    }

    /// One pinch with scale 2 on the picture, and the zoom above 100.
    private func pinch(_ picture: XCUIElement, _ app: XCUIApplication) {
        let before = info(app)
        print("clip-path: the pinch with scale 2 on editor.picture at the playhead " + playhead(app))
        picture.pinch(withScale: 2, velocity: 1)
        waitUntil("a zoom above 100 after a pinch with scale 2") { self.zoom(app) > 100 }
        print("clip-path: clip.frameInfo before the pinch reads " + before + " and after it " + info(app))
    }

    /// One tap on `editor.undo` and `clip.frameInfo` reads the line.
    private func undo(_ app: XCUIApplication, to line: String) {
        tapOn(app, "editor.undo")
        waitUntil("clip.frameInfo reading " + line + " after one undo") { self.info(app) == line }
    }

    /// The label of `start.draftsInfo`, read when `start.newProject` exists. Empty when it does not come.
    private func draftsInfo(_ app: XCUIApplication) -> String {
        waitUntil("start.newProject on the start screen", expected: expectedStart) {
            self.element(app, "start.newProject").exists
        }
        let line = element(app, "start.draftsInfo")
        let label = line.exists ? line.label : ""
        print("clip-path: start.draftsInfo reads " + label)
        return label
    }

    private func info(_ app: XCUIApplication) -> String {
        let line = app.staticTexts["clip.frameInfo"]
        return line.exists ? line.label : ""
    }

    private func zoom(_ app: XCUIApplication) -> Int {
        zoom(of: info(app))
    }

    /// Field 3 of a framing line, the zoom times 100, or 0 when it has none.
    private func zoom(of line: String) -> Int {
        let fields = line.split(separator: " ")
        return fields.count == 4 ? Int(fields[2]) ?? 0 : 0
    }

    /// The source start in ticks of a block's value, or -1 when it has none.
    private func sourceStart(_ value: String) -> Int {
        let fields = value.split(separator: " ")
        guard fields.count > 1, let start = fields[1].split(separator: "+").first else {
            return -1
        }
        return Int(start) ?? -1
    }

    private func soundInfo(_ app: XCUIApplication) -> String {
        let line = app.staticTexts["editor.soundInfo"]
        return line.exists ? line.label : ""
    }

    /// The field of `editor.soundInfo` at the place, counted from 1, or nothing when there is none.
    private func field(_ app: XCUIApplication, _ place: Int) -> String {
        let fields = soundInfo(app).split(separator: " ")
        return place <= fields.count ? String(fields[place - 1]) : ""
    }

    /// The time of `editor.time` before its slash, "mm:ss". Such texts are in the order of their times.
    private func time(_ app: XCUIApplication) -> String {
        element(app, "editor.time").label.components(separatedBy: " / ").first ?? ""
    }

    /// The value of `editor.playhead`, or "none" off the editor, as on the start screen or under the saved panel.
    private func playhead(_ app: XCUIApplication) -> String {
        let line = element(app, "editor.playhead")
        return line.exists ? line.value as? String ?? "" : "none"
    }

    /// The value of the element, empty when there is none: a read of a missing element fails the test.
    private func value(_ app: XCUIApplication, _ identifier: String) -> String {
        let found = element(app, identifier)
        return found.exists ? found.value as? String ?? "" : ""
    }

    private func values(_ app: XCUIApplication, _ count: Int) -> [String] {
        (1...count).map { value(app, "editor.clip." + String($0)) }
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Prints the seconds of the step that ends here and the seconds since the start of the walk.
    private func stepDone(_ what: String) {
        let now = Date()
        print(
            "clip-path: step \(what) took \(now.timeIntervalSince(stepBegan)) seconds, \(now.timeIntervalSince(walkBegan)) since the start of the walk"
        )
        stepBegan = now
    }

    /// Reads until the condition holds, prints the seconds it waited and fails only above three times the expected
    /// seconds: a hosted runner under load can hold the app for seconds. With `failing` false it only waits.
    private func waitUntil(_ what: String, expected: Double = 1, failing: Bool = true, _ reached: () -> Bool) {
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
        print("clip-path: waited \(waited) seconds for \(what), expected \(expected), limit \(3 * expected)")
        if failing {
            XCTAssertTrue(holds, what)
        }
    }
}
