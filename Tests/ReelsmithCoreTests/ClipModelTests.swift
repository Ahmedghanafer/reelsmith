import Foundation
import ReelsmithCore
import XCTest

/// Holds the kind of a media, the volume of a clip, the length of a photo clip, the still segments of the plan and
/// `clipInfo`, from the seed `photo-wide`.
final class ClipModelTests: XCTestCase {
    /// A draft of `two-clips-wide` at 1080p and 30, as a draft of version 1 was written: no clip has `volume` and
    /// no media fact has `kind`.
    private let versionOne = #"{"changed":813704709,"exportSettings":{"rate":{"thirty":{}},"size":{"hd1080":{}}},"project":{"canvas":{"landscape":{}},"clipVolume":1,"clips":[{"duration":{"ticks":1800},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0}},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0}}],"clipsMuted":false,"media":[{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080},{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920}],"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}"#

    private func sendSound(_ state: EditorState, _ action: SoundAction) -> EditorState {
        reduce(state, .sound(action))
    }

    private func playing(_ project: Project) -> EditorState {
        var state = EditorState(project: project)
        state.isPlaying = true
        return state
    }

    func testAVersionOneTextDecodesWithEachClipAtOneAndEachMediaAVideo() throws {
        let draft = try decodeDraft(Data(versionOne.utf8))

        XCTAssertEqual(draft.version, 1)
        XCTAssertEqual(draft.project, Seed.twoClipsWide.project)
        XCTAssertEqual(draft.project.clips.map(\.volume), [1, 1])
        XCTAssertEqual(draft.project.media.count, 2)
        for info in draft.project.media.values {
            XCTAssertEqual(info.kind, .video, info.id.raw)
        }
    }

    func testADraftOfPhotoWideWithAClipAtAVolumeRoundTripsAtVersionOne() throws {
        var project = Seed.photoWide.project
        project.clips[1].volume = 0.35
        let draft = Draft(
            project: project, exportSettings: .startChoice, changed: Date(timeIntervalSince1970: 1_792_011_909))

        let back = try decodeDraft(try encodeDraft(draft))

        XCTAssertEqual(back, draft)
        XCTAssertEqual(back.project.clips[1].volume, 0.35)
        XCTAssertEqual(back.project.media[MediaID("magenta")]?.kind, .photo)
        XCTAssertEqual(back.version, 1)
        XCTAssertEqual(Draft.version, 1)
    }

    func testTheTwoLengthsOfAPhoto() {
        XCTAssertEqual(MediaInfo.photoLength, Time(ticks: 1800))
        XCTAssertEqual(MediaInfo.photoLongest, Time(ticks: 108000))
    }

    func testAPhotoIsAddedForThreeSecondsAndTrimmedWithinThreeMinutes() throws {
        let added = reduce(EditorState(project: Project(canvas: .landscape)), .addClips([TestPhoto.magenta.info]))
        let clip = try XCTUnwrap(added.project.clips.first)

        XCTAssertEqual(added.project.clips.count, 1)
        XCTAssertEqual(clip.sourceStart, .zero)
        XCTAssertEqual(clip.duration, Time(ticks: 1800))

        let longer = reduce(added, .trimEnd(clip.id, by: Time(ticks: -600)))
        XCTAssertEqual(longer.project.clips[0].duration, Time(ticks: 2400))

        let longest = reduce(added, .trimEnd(clip.id, by: Time(ticks: -200000)))
        XCTAssertEqual(longest.project.clips[0].duration, Time(ticks: 108000))

        let earlier = reduce(added, .trimStart(clip.id, by: Time(ticks: -600)))
        XCTAssertEqual(earlier.project, added.project)
    }

    func testATestClipIsStillAddedWhole() {
        let added = reduce(EditorState(project: Project()), .addClips([TestClip.red.info]))

        XCTAssertEqual(added.project.clips.map(\.duration), [Time(ticks: 2400)])
        XCTAssertEqual(added.project.clips.map(\.sourceStart), [.zero])
    }

    func testASplitGivesBothHalvesTheVolumeOfTheClip() {
        var project = Seed.twoClipsWide.project
        project.clips[0].volume = 0.4
        var state = EditorState(project: project)
        state.playhead = Time(ticks: 600)

        let split = reduce(state, .split)

        XCTAssertEqual(split.project.clips.count, 3)
        XCTAssertEqual(split.project.clips.map(\.volume), [0.4, 0.4, 1])
    }

    func testADeleteKeepsTheVolumeOfTheClipsLeft() {
        var project = Seed.threeClips.project
        project.clips[0].volume = 0.4
        project.clips[2].volume = 0.7
        var state = EditorState(project: project)
        state.selection = ClipID(2)

        let deleted = reduce(state, .deleteSelected)

        XCTAssertEqual(deleted.project.clips.map(\.id), [ClipID(1), ClipID(3)])
        XCTAssertEqual(deleted.project.clips.map(\.volume), [0.4, 0.7])
    }

    func testTheVolumeOfAClipIsHeldBetweenZeroAndTwoAndPlaysOn() {
        var project = Seed.photoWide.project
        for index in project.clips.indices {
            project.clips[index].volume = 0.5
        }
        let state = playing(project)

        let above = sendSound(state, .setVolumeOfClip(ClipID(1), 2.5))
        XCTAssertEqual(above.project.clips.map(\.volume), [2, 0.5, 0.5])
        XCTAssertTrue(above.isPlaying)

        let below = sendSound(state, .setVolumeOfClip(ClipID(1), -1))
        XCTAssertEqual(below.project.clips.map(\.volume), [0, 0.5, 0.5])
        XCTAssertTrue(below.isPlaying)

        let quarter = sendSound(state, .setVolumeOfClip(ClipID(2), 0.25))
        XCTAssertEqual(quarter.project.clips.map(\.volume), [0.5, 0.25, 0.5])
        XCTAssertTrue(quarter.isPlaying)
        XCTAssertEqual(quarter.project.clipVolume, 1)
    }

    func testAVolumeOfAClipThatChangesNothingReturnsTheStateUnchanged() {
        var project = Seed.photoWide.project
        project.clips[0].volume = 0.5
        let state = playing(project)

        XCTAssertEqual(sendSound(state, .setVolumeOfClip(ClipID(9), 0.25)), state)
        XCTAssertEqual(sendSound(state, .setVolumeOfClip(ClipID(1), 0.5)), state)
        XCTAssertEqual(sendSound(state, .setVolumeOfClip(ClipID(1), .nan)), state)
        XCTAssertEqual(sendSound(state, .setVolumeOfClip(ClipID(1), .infinity)), state)
        XCTAssertEqual(sendSound(state, .setVolumeOfClip(ClipID(1), -.infinity)), state)
    }

    func testNoOtherActionChangesTheVolumeOfAClip() {
        var project = Seed.photoWide.project
        for index in project.clips.indices {
            project.clips[index].volume = 0.4
        }
        project.music = Music(file: TestTone.long.file)
        var start = EditorState(project: project)
        start.playhead = Time(ticks: 600)
        start.selection = ClipID(1)
        let added = reduce(start, .text(.add))
        let text = TextID(1)
        let actions: [EditorAction] = [
            .addClips([TestClip.green.info]), .split, .trimStart(ClipID(1), by: Time(ticks: 300)),
            .trimEnd(ClipID(3), by: Time(ticks: 300)), .deleteSelected, .select(ClipID(2)), .clearSelection,
            .movePlayhead(Time(ticks: 900)), .play, .pause,
            .text(.add), .text(.select(text)), .text(.setString(text, "Peace")), .text(.setStyle(text, .standard)),
            .text(.move(text, x: 100, y: 100)), .text(.turn(text, to: 45)), .text(.trimStart(text, by: Time(ticks: 60))),
            .text(.trimEnd(text, by: Time(ticks: 60))),
            .sound(.open), .sound(.setClipVolume(0.2)), .sound(.muteClips(true)), .sound(.setMusic(TestTone.short.file)),
            .sound(.setMusicVolume(0.3)), .sound(.setMusicStart(Time(ticks: 600))), .sound(.setFadeIn(Time(ticks: 300))),
            .sound(.setFadeOut(Time(ticks: 300))), .sound(.removeMusic),
        ]

        for action in actions {
            for before in [start, added] {
                let after = reduce(before, action)
                for clip in after.project.clips where before.project.position(of: clip.id) != nil {
                    XCTAssertEqual(clip.volume, 0.4, "\(action) on clip \(clip.id.raw)")
                }
            }
        }
    }

    func testThePlanOfPhotoWideHasAStillSegmentInTheMiddle() throws {
        let plan = try renderPlan(for: Seed.photoWide.project)

        XCTAssertEqual(plan.segments.count, 3)
        XCTAssertEqual(plan.segments.map(\.isStill), [false, true, false])
        XCTAssertEqual(plan.segments.map(\.hasSound), [true, false, true])
        XCTAssertEqual(
            plan.segments[1].placement, Placement(quarterTurns: 0, x: 555, y: 0, width: 810, height: 1080))
        XCTAssertEqual(plan.segments.map(\.volume), [1, 1, 1])
    }

    func testAClipAtAVolumeGivesItsSegmentThatVolumeAndTheClipsKeepTheirs() throws {
        var project = Seed.photoWide.project
        project.clips[2].volume = 0.35

        let plan = try renderPlan(for: project)

        XCTAssertEqual(plan.segments.map(\.volume), [1, 1, 0.35])
        XCTAssertEqual(plan.sound.clipVolume, 1)
    }

    func testTheInfoOfEachClipOfPhotoWide() {
        let project = Seed.photoWide.project

        XCTAssertEqual(project.clipInfo(ClipID(1)), "blue 0+1800 100 v")
        XCTAssertEqual(project.clipInfo(ClipID(2)), "magenta 0+1800 100 p")
        XCTAssertEqual(project.clipInfo(ClipID(3)), "red 0+2400 100 v")
        XCTAssertNil(project.clipInfo(ClipID(9)))

        let quieter = reduce(EditorState(project: project), .sound(.setVolumeOfClip(ClipID(1), 0.355)))
        XCTAssertEqual(quieter.project.clipInfo(ClipID(1)), "blue 0+1800 36 v")
    }
}
