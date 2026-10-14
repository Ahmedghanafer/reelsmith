import ReelsmithCore
import XCTest

final class SoundStateTests: XCTestCase {
    private func state(_ change: (inout Project) -> Void) -> EditorState {
        var project = Seed.musicWide.project
        change(&project)
        return EditorState(project: project)
    }

    /// Every value of sound away from the one a new music has.
    private func changed(_ project: inout Project) {
        project.clipVolume = 0.5
        project.clipsMuted = true
        project.music?.start = Time(ticks: 600)
        project.music?.volume = 0.25
        project.music?.fadeIn = Time(ticks: 300)
        project.music?.fadeOut = Time(ticks: 3000)
    }

    func testANewStateDoesNotShowTheSoundPanel() {
        XCTAssertFalse(EditorState(project: Seed.musicWide.project).showsSound)
        XCTAssertFalse(EditorState(project: Seed.empty.project).showsSound)
    }

    func testTheSoundPanelCanOpenOnlyOnAProjectWithAClip() {
        XCTAssertTrue(EditorState(project: Seed.twoClipsWide.project).canOpenSound)
        XCTAssertFalse(EditorState(project: Seed.empty.project).canOpenSound)
    }

    func testClearSelectionClosesTheSoundPanel() {
        var open = EditorState(project: Seed.musicWide.project)
        open.showsSound = true

        XCTAssertFalse(reduce(open, .clearSelection).showsSound)
    }

    func testTheStartCanBeSetOnlyWhenAStepFitsBeforeTheLargestStart() {
        XCTAssertTrue(EditorState(project: Seed.musicWide.project).canSetMusicStart)
        XCTAssertTrue(state { $0.music = Music(file: TestTone.short.file) }.canSetMusicStart)
        XCTAssertFalse(state { $0.music = Music(file: musicFile(ticks: 900)) }.canSetMusicStart)
        XCTAssertFalse(EditorState(project: Seed.twoClipsWide.project).canSetMusicStart)
    }

    func testSoundInfoOfTheTwoSeeds() {
        XCTAssertEqual(EditorState(project: Seed.twoClipsWide.project).soundInfo, "100 . none")
        XCTAssertEqual(EditorState(project: Seed.musicWide.project).soundInfo, "100 . 0+4200 100 0 0")
    }

    func testSoundInfoReadsEveryValueWithTheFadesAsStored() {
        XCTAssertEqual(state { self.changed(&$0) }.soundInfo, "50 m 600+4200 25 300 3000")
    }

    func testSoundInfoReadsHiddenForMusicWithNoClip() {
        let noClip = state {
            self.changed(&$0)
            $0.clips = []
        }

        XCTAssertEqual(noClip.soundInfo, "50 m hidden 25 300 3000")
    }

    func testTheMusicLabelGivesTheTimesHeardOfTheFileAndItsLength() {
        XCTAssertEqual(EditorState(project: Seed.musicWide.project).musicLabel, "00:00-00:07 / 00:10")
        XCTAssertEqual(state { $0.music?.start = Time(ticks: 3000) }.musicLabel, "00:05-00:10 / 00:10")
    }

    func testThereIsNoMusicLabelWithNoMusicAndWithNoClip() {
        XCTAssertNil(EditorState(project: Seed.twoClipsWide.project).musicLabel)
        XCTAssertNil(state { $0.clips = [] }.musicLabel)
    }
}
