import ReelsmithCore
import XCTest

/// A level changed while the video plays: the six levels leave isPlaying as it was, every other sound action that
/// changes the state pauses, and `sameTracks` tells a change of levels from a change of the tracks.
final class LiveLevelsTests: XCTestCase {
    private let red = ClipID(2)
    private let music = EditorState(project: Seed.musicWide.project)
    private let wide = EditorState(project: Seed.twoClipsWide.project)

    private func playing(_ state: EditorState) -> EditorState {
        var next = state
        next.isPlaying = true
        return next
    }

    private func ticks(_ value: Int64) -> Time {
        Time(ticks: value)
    }

    private let levels: [SoundAction] = [
        .setClipVolume(0.5), .muteClips(true), .setVolumeOfClip(ClipID(2), 0.5), .setMusicVolume(0.25),
        .setFadeIn(Time(ticks: 600)), .setFadeOut(Time(ticks: 600)),
    ]

    func testEachLevelThatChangesTheStateWhilePlayingLeavesItPlaying() {
        for action in levels {
            let next = reduce(playing(music), .sound(action))
            XCTAssertNotEqual(next.project, music.project, "\(action) changed nothing")
            XCTAssertTrue(next.isPlaying, "\(action)")
        }
    }

    func testEachLevelThatChangesTheStateWhilePausedLeavesItPaused() {
        for action in levels {
            let next = reduce(music, .sound(action))
            XCTAssertNotEqual(next.project, music.project, "\(action) changed nothing")
            XCTAssertFalse(next.isPlaying, "\(action)")
        }
    }

    func testSetMusicRemoveMusicAndSetMusicStartThatChangeTheStateStillPause() {
        let actions: [(EditorState, SoundAction)] = [
            (playing(wide), .setMusic(TestTone.long.file)), (playing(music), .setMusic(TestTone.short.file)),
            (playing(music), .removeMusic), (playing(music), .setMusicStart(ticks(600))),
        ]
        for (state, action) in actions {
            let next = reduce(state, .sound(action))
            XCTAssertNotEqual(next.project, state.project, "\(action) changed nothing")
            XCTAssertFalse(next.isPlaying, "\(action)")
        }
    }

    func testEverySoundActionThatChangesNothingReturnsTheStateUnchanged() {
        let onMusic: [SoundAction] = [
            .setClipVolume(1), .setClipVolume(.nan), .muteClips(false), .setVolumeOfClip(red, 1),
            .setVolumeOfClip(ClipID(9), 0.5), .setVolumeOfClip(red, .nan), .setMusic(TestTone.long.file),
            .setMusicVolume(1), .setMusicVolume(.infinity), .setMusicStart(.zero), .setFadeIn(.zero),
            .setFadeOut(.zero),
        ]
        for action in onMusic {
            XCTAssertEqual(reduce(playing(music), .sound(action)), playing(music), "\(action)")
        }
        let onWide: [SoundAction] = [
            .removeMusic, .setMusicVolume(0.5), .setMusicStart(ticks(600)), .setFadeIn(ticks(600)),
            .setFadeOut(ticks(600)),
        ]
        for action in onWide {
            XCTAssertEqual(reduce(playing(wide), .sound(action)), playing(wide), "\(action)")
        }
    }

    // sameTracks

    func testSameTracksHoldsWhenOnlyTheLevelsDiffer() {
        let base = Seed.musicWide.project
        var changes: [(String, Project)] = []
        var project = base
        project.clipVolume = 0.5
        changes.append(("the volume of the clips", project))
        project = base
        project.clipsMuted = true
        changes.append(("the mute", project))
        project = base
        project.clips[1].volume = 0.5
        changes.append(("the volume of red", project))
        project = base
        project.music?.volume = 0.25
        changes.append(("the volume of the music", project))
        project = base
        project.music?.fadeIn = ticks(600)
        changes.append(("the fade in", project))
        project = base
        project.music?.fadeOut = ticks(600)
        changes.append(("the fade out", project))
        project.clipVolume = 0.5
        project.clipsMuted = true
        project.clips[0].volume = 0
        project.music?.volume = 0
        project.music?.fadeIn = ticks(300)
        changes.append(("every level at once", project))

        for (what, changed) in changes {
            XCTAssertTrue(base.sameTracks(as: changed), what)
            XCTAssertTrue(changed.sameTracks(as: base), what)
            XCTAssertFalse(base.sameFootage(as: changed), what)
        }
    }

    func testSameTracksFailsForAClipMovedCutOrTrimmedAnotherMediaCanvasMusicFileOrStart() {
        let base = Seed.musicWide.project
        var changes: [(String, Project)] = []
        var project = base
        project.clips.reverse()
        changes.append(("red moved before blue", project))
        project = base
        let blue = project.clips[0]
        project.clips[0].duration = ticks(900)
        project.clips.insert(
            Clip(id: ClipID(project.nextClipID), media: blue.media, sourceStart: ticks(900), duration: ticks(900)),
            at: 1)
        project.nextClipID += 1
        changes.append(("blue cut in two", project))
        project = base
        project.clips[1].duration = ticks(1800)
        changes.append(("red trimmed at its end", project))
        project = base
        project.clips[1].sourceStart = ticks(600)
        project.clips[1].duration = ticks(1800)
        changes.append(("red trimmed at its start", project))
        project = base
        project.media[blue.media]?.width = 640
        changes.append(("another media", project))
        project = base
        project.canvas = .portrait
        changes.append(("another canvas", project))
        project = base
        project.music = Music(file: TestTone.short.file)
        changes.append(("another music file", project))
        project = base
        project.music = nil
        changes.append(("no music", project))
        project = base
        project.music?.start = ticks(600)
        changes.append(("another start of the music", project))

        for (what, changed) in changes {
            XCTAssertFalse(base.sameTracks(as: changed), what)
            XCTAssertFalse(changed.sameTracks(as: base), what)
        }
    }
}
