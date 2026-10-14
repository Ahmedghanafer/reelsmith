import ReelsmithCore
import XCTest

final class SoundEditsTests: XCTestCase {
    private let one = TextID(1)
    private let blue = ClipID(1)
    private let red = ClipID(2)
    private let wide = EditorState(project: Seed.twoClipsWide.project)
    private let music = EditorState(project: Seed.musicWide.project)
    private let textWide = EditorState(project: Seed.textWide.project)

    private func assertValid(_ state: EditorState, line: UInt = #line) {
        let project = state.project
        XCTAssertGreaterThanOrEqual(project.clipVolume, 0, "the volume of the clips", line: line)
        XCTAssertLessThanOrEqual(project.clipVolume, 1, "the volume of the clips", line: line)
        if let music = project.music {
            XCTAssertGreaterThanOrEqual(music.volume, 0, "the volume of the music", line: line)
            XCTAssertLessThanOrEqual(music.volume, 1, "the volume of the music", line: line)
            XCTAssertEqual(music.start.ticks % Time.frame.ticks, 0, "the start of the music", line: line)
            XCTAssertGreaterThanOrEqual(music.start, Time.zero, "the start of the music", line: line)
            XCTAssertLessThanOrEqual(music.start, music.largestStart, "the start of the music", line: line)
            for fade in [music.fadeIn, music.fadeOut] {
                XCTAssertEqual(fade.ticks % Time.frame.ticks, 0, "a fade", line: line)
                XCTAssertGreaterThanOrEqual(fade, Time.zero, "a fade", line: line)
                XCTAssertLessThanOrEqual(fade, SoundGeometry.maximumFade, "a fade", line: line)
            }
            XCTAssertGreaterThan(music.file.duration, Time.zero, "the length of the file", line: line)
        }
        let set = [state.selection != nil, state.selectedText != nil, state.showsSound].filter { $0 }
        XCTAssertLessThanOrEqual(set.count, 1, "more than one of a clip, a text and the sound panel", line: line)
        if project.clips.isEmpty {
            XCTAssertFalse(state.showsSound, "the sound panel on an empty project", line: line)
        }
    }

    /// Sends the actions one by one. The state must be valid after each.
    private func send(_ state: EditorState, _ actions: EditorAction..., line: UInt = #line) -> EditorState {
        var next = state
        for action in actions {
            next = reduce(next, action)
            assertValid(next, line: line)
        }
        return next
    }

    private func sendSound(_ state: EditorState, _ actions: SoundAction..., line: UInt = #line) -> EditorState {
        var next = state
        for action in actions {
            next = reduce(next, .sound(action))
            assertValid(next, line: line)
        }
        return next
    }

    private func playing(_ state: EditorState) -> EditorState {
        var next = state
        next.isPlaying = true
        return next
    }

    private func ticks(_ value: Int64) -> Time {
        Time(ticks: value)
    }

    /// The music seed with every value of sound away from the one it starts with, playing.
    private var changed: EditorState {
        playing(
            sendSound(
                music, .setClipVolume(0.5), .muteClips(true), .setMusicStart(ticks(600)), .setMusicVolume(0.25),
                .setFadeIn(ticks(300)), .setFadeOut(ticks(300))))
    }

    /// The three values of sound.
    private func sound(_ state: EditorState) -> [String] {
        [String(state.project.clipVolume), String(state.project.clipsMuted), String(describing: state.project.music)]
    }

    private func field(_ number: Int, of state: EditorState) -> String {
        let fields = state.soundInfo.split(separator: " ").map(String.init)
        return number <= fields.count ? fields[number - 1] : "missing"
    }

    // Open

    func testOpenShowsThePanelAndLeavesPlayingAlone() {
        let stopped = sendSound(wide, .open)
        XCTAssertTrue(stopped.showsSound)
        XCTAssertFalse(stopped.isPlaying)

        let moving = sendSound(playing(wide), .open)
        XCTAssertTrue(moving.showsSound)
        XCTAssertTrue(moving.isPlaying)
    }

    func testOpenClearsTheSelectedClip() {
        let selected = send(wide, .select(blue))
        XCTAssertEqual(selected.selection, blue)

        let next = sendSound(selected, .open)

        XCTAssertNil(next.selection)
        XCTAssertTrue(next.showsSound)
    }

    func testOpenClearsTheSelectedTextAndKeepsIt() {
        var selected = textWide
        selected.selectedText = one

        let next = sendSound(selected, .open)

        XCTAssertNil(next.selectedText)
        XCTAssertNotNil(next.project.text(one))
        XCTAssertTrue(next.showsSound)
    }

    func testOpenAfterAddRemovesTheBlankText() {
        let added = send(wide, .text(.add))
        XCTAssertEqual(added.project.texts.count, 1)

        let next = sendSound(added, .open)

        XCTAssertEqual(next.project.texts, [])
        XCTAssertNil(next.selectedText)
        XCTAssertTrue(next.showsSound)
    }

    func testOpenOnAnEmptyProjectChangesNothing() {
        let empty = EditorState(project: Seed.empty.project)

        XCTAssertEqual(sendSound(empty, .open), empty)
        XCTAssertEqual(sendSound(playing(empty), .open), playing(empty))
    }

    // The one of three

    func testSelectingAClipClosesThePanel() {
        let next = send(music, .sound(.open), .select(blue))

        XCTAssertFalse(next.showsSound)
        XCTAssertEqual(next.selection, blue)
    }

    func testSelectingATextClosesThePanel() {
        let next = send(textWide, .sound(.open), .text(.select(one)))

        XCTAssertFalse(next.showsSound)
        XCTAssertEqual(next.selectedText, one)
    }

    func testAddingATextClosesThePanel() {
        let next = send(music, .sound(.open), .text(.add))

        XCTAssertFalse(next.showsSound)
        XCTAssertNotNil(next.selectedText)
        XCTAssertEqual(next.selectedText, next.project.texts.last?.id)
    }

    func testClearSelectionLeavesNothingSet() {
        let next = send(music, .sound(.open), .clearSelection)

        XCTAssertFalse(next.showsSound)
        XCTAssertNil(next.selection)
        XCTAssertNil(next.selectedText)
    }

    func testThePlayheadAndPlayingLeaveThePanelAsItWas() {
        for start in [music, sendSound(music, .open)] {
            for action in [EditorAction.movePlayhead(ticks(600)), .play, .pause] {
                XCTAssertEqual(send(start, action).showsSound, start.showsSound, "\(action)")
            }
        }
    }

    func testEverySoundActionButOpenLeavesThePanelAsItWas() {
        let actions: [SoundAction] = [
            .setClipVolume(0.5), .muteClips(true), .setMusic(TestTone.short.file), .removeMusic,
            .setMusicVolume(0.5), .setMusicStart(ticks(600)), .setFadeIn(ticks(300)), .setFadeOut(ticks(300)),
        ]
        for start in [music, sendSound(music, .open)] {
            for action in actions {
                let next = sendSound(start, action)
                XCTAssertNotEqual(next.project, start.project, "\(action) changed nothing")
                XCTAssertEqual(next.showsSound, start.showsSound, "\(action)")
            }
        }
    }

    func testDeletingEveryClipWithThePanelOpenLeavesItClosed() {
        var next = sendSound(music, .open)
        while let first = next.project.clips.first {
            next = send(next, .select(first.id), .deleteSelected)
        }

        XCTAssertEqual(next.project.clips, [])
        XCTAssertFalse(next.showsSound)
    }

    func testAnyActionOnAnEmptyProjectClosesThePanel() {
        // Only a state made by hand has the panel open on an empty project.
        var start = EditorState(project: Seed.musicWide.project)
        start.project.clips = []
        start.showsSound = true

        XCTAssertFalse(send(start, .pause).showsSound)
    }

    // The volume of the clips

    func testSetClipVolumeStoresTheVolumeAndPauses() {
        let next = sendSound(playing(music), .setClipVolume(0.5))

        XCTAssertEqual(next.project.clipVolume, 0.5)
        XCTAssertFalse(next.isPlaying)
    }

    func testSetClipVolumeIsHeldBetweenZeroAndOne() {
        let half = sendSound(music, .setClipVolume(0.5))

        XCTAssertEqual(sendSound(half, .setClipVolume(1.7)).project.clipVolume, 1)
        XCTAssertEqual(sendSound(half, .setClipVolume(-0.3)).project.clipVolume, 0)
    }

    func testSetClipVolumeWithItsOwnValueChangesNothing() {
        XCTAssertEqual(sendSound(playing(music), .setClipVolume(1)), playing(music))
        XCTAssertEqual(sendSound(playing(music), .setClipVolume(1.7)), playing(music))
        XCTAssertEqual(sendSound(changed, .setClipVolume(0.5)), changed)
    }

    func testSetClipVolumeThatIsNotFiniteChangesNothing() {
        for volume in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(sendSound(changed, .setClipVolume(volume)), changed, "\(volume)")
        }
    }

    func testSetClipVolumeWorksWithThePanelClosedAndLeavesItAlone() {
        let closed = sendSound(music, .setClipVolume(0.5))
        XCTAssertEqual(closed.project.clipVolume, 0.5)
        XCTAssertFalse(closed.showsSound)

        let open = sendSound(music, .open, .setClipVolume(0.5))
        XCTAssertEqual(open.project.clipVolume, 0.5)
        XCTAssertTrue(open.showsSound)
    }

    // The mute

    func testMuteKeepsTheVolumeAndThePlanReadsZero() throws {
        let half = sendSound(music, .setClipVolume(0.5))

        let muted = sendSound(playing(half), .muteClips(true))
        XCTAssertTrue(muted.project.clipsMuted)
        XCTAssertEqual(muted.project.clipVolume, 0.5)
        XCTAssertFalse(muted.isPlaying)
        XCTAssertEqual(try renderPlan(for: muted.project).sound.clipVolume, 0)

        let unmuted = sendSound(muted, .muteClips(false))
        XCTAssertFalse(unmuted.project.clipsMuted)
        XCTAssertEqual(try renderPlan(for: unmuted.project).sound.clipVolume, 0.5)
    }

    func testMuteWithItsOwnValueChangesNothing() {
        XCTAssertEqual(sendSound(playing(music), .muteClips(false)), playing(music))
        XCTAssertEqual(sendSound(changed, .muteClips(true)), changed)
    }

    // Set and remove the music

    func testSetMusicStoresANewMusicAndPauses() {
        let next = sendSound(playing(wide), .setMusic(TestTone.long.file))

        XCTAssertEqual(next.project.music, Music(file: TestTone.long.file))
        XCTAssertFalse(next.isPlaying)
    }

    func testSetMusicReplacesTheMusicWhole() {
        let set = sendSound(music, .setMusicStart(ticks(600)), .setMusicVolume(0.5), .setFadeIn(ticks(300)))
        XCTAssertEqual(
            set.project.music,
            Music(file: TestTone.long.file, start: ticks(600), volume: 0.5, fadeIn: ticks(300), fadeOut: .zero))

        let next = sendSound(set, .setMusic(TestTone.short.file))

        XCTAssertEqual(
            next.project.music,
            Music(file: TestTone.short.file, start: .zero, volume: 1, fadeIn: .zero, fadeOut: .zero))
    }

    func testSetMusicWithAFileOfNoLengthChangesNothing() {
        XCTAssertEqual(sendSound(playing(wide), .setMusic(musicFile(ticks: 0))), playing(wide))
        XCTAssertEqual(sendSound(changed, .setMusic(musicFile(ticks: 0))), changed)
    }

    func testSetMusicWithTheMusicItAlreadyHasChangesNothing() {
        XCTAssertEqual(sendSound(playing(music), .setMusic(TestTone.long.file)), playing(music))
    }

    func testRemoveMusicKeepsTheSoundOfTheClips() {
        let removed = sendSound(playing(music), .removeMusic)
        XCTAssertNil(removed.project.music)
        XCTAssertEqual(removed.soundInfo, "100 . none")
        XCTAssertFalse(removed.isPlaying)

        let next = sendSound(changed, .removeMusic)
        XCTAssertNil(next.project.music)
        XCTAssertEqual(next.project.clipVolume, 0.5)
        XCTAssertTrue(next.project.clipsMuted)
    }

    // The volume of the music

    func testSetMusicVolumeStoresTheVolumeHeldBetweenZeroAndOne() {
        let quarter = sendSound(playing(music), .setMusicVolume(0.25))
        XCTAssertEqual(quarter.project.music?.volume, 0.25)
        XCTAssertFalse(quarter.isPlaying)

        XCTAssertEqual(sendSound(quarter, .setMusicVolume(2)).project.music?.volume, 1)
        XCTAssertEqual(sendSound(quarter, .setMusicVolume(-1)).project.music?.volume, 0)
    }

    // The start of the music

    private func startAfter(_ value: Int64, from state: EditorState? = nil, line: UInt = #line) -> Int64? {
        sendSound(state ?? music, .setMusicStart(ticks(value)), line: line).project.music?.start.ticks
    }

    func testSetMusicStartIsHeldAndRoundedTowardZeroToAWholeFrame() {
        let atSix = sendSound(music, .setMusicStart(ticks(600)))

        XCTAssertEqual(startAfter(600), 600)
        XCTAssertEqual(startAfter(619), 600)
        XCTAssertEqual(startAfter(-50, from: atSix), 0)
        XCTAssertEqual(startAfter(9000), 5400)
    }

    func testTheLargestStartLeavesSixHundredTicksHeard() {
        let next = sendSound(playing(music), .setMusicStart(ticks(9000)))

        XCTAssertEqual(next.project.music?.start, ticks(5400))
        XCTAssertEqual(next.project.heardMusic, ticks(600))
        XCTAssertFalse(next.isPlaying)
    }

    func testTheLargestStartOfTheShortToneIs600() {
        let short = sendSound(wide, .setMusic(TestTone.short.file))

        XCTAssertEqual(startAfter(9000, from: short), 600)
        XCTAssertEqual(startAfter(400, from: short), 400)
    }

    func testAFileOf500TicksKeepsItsStartAtZero() {
        let small = sendSound(wide, .setMusic(musicFile(ticks: 500)))

        for value: Int64 in [20, 600, 9000, -50] {
            XCTAssertEqual(startAfter(value, from: small), 0, "\(value)")
            XCTAssertEqual(sendSound(playing(small), .setMusicStart(ticks(value))), playing(small), "\(value)")
        }
    }

    func testAStartOf3000ReadsInTheLabelAndTheInfo() {
        let next = sendSound(music, .setMusicStart(ticks(3000)))

        XCTAssertEqual(next.musicLabel, "00:05-00:10 / 00:10")
        XCTAssertEqual(field(3, of: next), "3000+3000")
    }

    // The fades

    private func fadeInAfter(_ value: Int64, from state: EditorState? = nil, line: UInt = #line) -> Int64? {
        sendSound(state ?? music, .setFadeIn(ticks(value)), line: line).project.music?.fadeIn.ticks
    }

    private func fadeOutAfter(_ value: Int64, from state: EditorState? = nil, line: UInt = #line) -> Int64? {
        sendSound(state ?? music, .setFadeOut(ticks(value)), line: line).project.music?.fadeOut.ticks
    }

    func testSetFadeInIsHeldAndRoundedTowardZeroToAWholeFrame() {
        let set = sendSound(music, .setFadeIn(ticks(300)))

        XCTAssertEqual(fadeInAfter(300), 300)
        XCTAssertEqual(fadeInAfter(310), 300)
        XCTAssertEqual(fadeInAfter(-5, from: set), 0)
        XCTAssertEqual(fadeInAfter(9000), 3000)
    }

    func testSetFadeOutIsHeldAndRoundedTowardZeroToAWholeFrame() {
        let set = sendSound(music, .setFadeOut(ticks(300)))

        XCTAssertEqual(fadeOutAfter(300), 300)
        XCTAssertEqual(fadeOutAfter(310), 300)
        XCTAssertEqual(fadeOutAfter(-5, from: set), 0)
        XCTAssertEqual(fadeOutAfter(9000), 3000)
    }

    func testEachFadeChangesOnlyItself() {
        let next = sendSound(music, .setFadeIn(ticks(300)), .setFadeOut(ticks(600)))

        XCTAssertEqual(next.project.music?.fadeIn, ticks(300))
        XCTAssertEqual(next.project.music?.fadeOut, ticks(600))
    }

    func testALongFadeIsStoredAsSentAndCutOnlyInThePlan() throws {
        let next = sendSound(music, .setFadeOut(ticks(3000)))

        XCTAssertEqual(field(5, of: next), "0")
        XCTAssertEqual(field(6, of: next), "3000")
        XCTAssertEqual(try renderPlan(for: next.project).sound.music?.fadeOut, ticks(2100))
    }

    // An action that changes nothing

    func testEveryActionOnTheMusicWithNoMusicChangesNothing() {
        let actions: [SoundAction] = [
            .removeMusic, .setMusicVolume(0.5), .setMusicStart(ticks(600)), .setFadeIn(ticks(300)),
            .setFadeOut(ticks(300)),
        ]
        for action in actions {
            XCTAssertEqual(sendSound(playing(wide), action), playing(wide), "\(action)")
        }
    }

    func testEveryActionOnTheMusicWithTheValueItHasChangesNothing() {
        let actions: [SoundAction] = [
            .setMusicVolume(0.25), .setMusicStart(ticks(600)), .setFadeIn(ticks(300)), .setFadeOut(ticks(300)),
            .setMusicStart(ticks(610)), .setFadeIn(ticks(319)), .setFadeOut(ticks(301)),
        ]
        for action in actions {
            XCTAssertEqual(sendSound(changed, action), changed, "\(action)")
        }
        let full: [SoundAction] = [
            .setMusicVolume(1), .setMusicVolume(2), .setMusicStart(.zero), .setFadeIn(.zero), .setFadeOut(.zero),
        ]
        for action in full {
            XCTAssertEqual(sendSound(playing(music), action), playing(music), "\(action)")
        }
    }

    func testAMusicVolumeThatIsNotFiniteChangesNothing() {
        for volume in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(sendSound(changed, .setMusicVolume(volume)), changed, "\(volume)")
        }
    }

    func testEveryActionOnTheMusicThatChangesItPauses() {
        let actions: [SoundAction] = [
            .removeMusic, .setMusicVolume(0.5), .setMusicStart(ticks(1200)), .setFadeIn(ticks(600)),
            .setFadeOut(ticks(600)),
        ]
        for action in actions {
            let next = sendSound(changed, action)
            XCTAssertNotEqual(next.project, changed.project, "\(action) changed nothing")
            XCTAssertFalse(next.isPlaying, "\(action)")
        }
    }

    // Clip and text actions

    func testNoClipActionAndNoTextActionChangesSound() {
        var next = changed
        let before = sound(next)
        func step(_ action: EditorAction) {
            next = send(next, action)
            XCTAssertEqual(sound(next), before, "\(action)")
        }

        step(.addClips([TestClip.green.info]))
        XCTAssertEqual(next.project.clips.count, 3)
        step(.movePlayhead(ticks(600)))
        step(.split)
        XCTAssertEqual(next.project.clips.count, 4)
        step(.trimStart(blue, by: ticks(60)))
        step(.trimEnd(blue, by: ticks(60)))
        XCTAssertEqual(next.project.clips.first?.duration, ticks(480))
        step(.text(.add))
        let text = next.selectedText ?? one
        step(.text(.setString(text, "Sound")))
        step(.text(.move(text, x: 100, y: 100)))
        XCTAssertEqual(next.project.text(text)?.x, 100)
        while let first = next.project.clips.first {
            step(.select(first.id))
            step(.deleteSelected)
        }

        XCTAssertEqual(next.project.clips, [])
        XCTAssertNil(next.project.heardMusic)
        XCTAssertEqual(field(3, of: next), "hidden")

        step(.addClips([TestClip.blue.info]))
        XCTAssertEqual(next.project.heardMusic, ticks(1800))
    }

    // Delete

    func testDeleteWithThePanelOpenAndNothingSelectedChangesNothing() {
        let open = sendSound(music, .open)

        XCTAssertFalse(open.canDelete)
        XCTAssertEqual(send(open, .deleteSelected), open)
        XCTAssertEqual(send(playing(open), .deleteSelected), playing(open))
    }
}
