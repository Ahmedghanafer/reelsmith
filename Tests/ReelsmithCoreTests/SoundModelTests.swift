import ReelsmithCore
import XCTest

/// A music file of that length, for a length no test tone has.
func musicFile(ticks: Int64) -> MusicFile {
    MusicFile(id: MediaID("file"), fileName: "file.m4a", title: "file", duration: Time(ticks: ticks))
}

final class SoundModelTests: XCTestCase {
    func testANewProjectHasFullClipSoundNoMuteAndNoMusic() {
        for project in [Project(), Project(canvas: .landscape)] {
            XCTAssertEqual(project.clipVolume, 1)
            XCTAssertFalse(project.clipsMuted)
            XCTAssertNil(project.music)
        }
    }

    func testAMusicMadeFromAFileBeginsAtZeroAtFullVolumeWithNoFade() {
        let file = TestTone.long.file

        XCTAssertEqual(
            Music(file: file), Music(file: file, start: .zero, volume: 1, fadeIn: .zero, fadeOut: .zero))
    }

    func testTheLimitsOfSoundAreFiveSecondsOfFadeOneSecondOfMusicAndAStepOfOneSecond() {
        XCTAssertEqual(SoundGeometry.maximumFade, Time(ticks: 3000))
        XCTAssertEqual(SoundGeometry.minimumMusic, Time(ticks: 600))
        XCTAssertEqual(SoundGeometry.startStep, Time(ticks: 600))
    }

    func testTheLargestStartLeavesOneSecondOfTheFileAndIsAWholeFrame() {
        XCTAssertEqual(Music(file: TestTone.long.file).largestStart, Time(ticks: 5400))
        XCTAssertEqual(Music(file: TestTone.short.file).largestStart, Time(ticks: 600))
        XCTAssertEqual(Music(file: musicFile(ticks: 900)).largestStart, Time(ticks: 300))
        XCTAssertEqual(Music(file: musicFile(ticks: 6010)).largestStart, Time(ticks: 5400))
    }

    func testTheLargestStartIsZeroForAFileNotLongerThanOneSecond() {
        XCTAssertEqual(Music(file: musicFile(ticks: 600)).largestStart, .zero)
        XCTAssertEqual(Music(file: musicFile(ticks: 500)).largestStart, .zero)
    }

    func testTheMusicIsHeardForTheSmallerOfWhatIsLeftOfTheFileAndTheProjectLength() {
        XCTAssertEqual(Seed.musicWide.project.heardMusic, Time(ticks: 4200))

        var blueAlone = Seed.musicWide.project
        blueAlone.clips.removeLast()
        XCTAssertEqual(blueAlone.heardMusic, Time(ticks: 1800))

        var lateStart = Seed.musicWide.project
        lateStart.music?.start = Time(ticks: 5400)
        XCTAssertEqual(lateStart.heardMusic, Time(ticks: 600))

        var shortFile = Seed.musicWide.project
        shortFile.music = Music(file: TestTone.short.file)
        XCTAssertEqual(shortFile.heardMusic, Time(ticks: 1200))
    }

    func testNothingIsHeardWithNoMusicAndWithNoClip() {
        XCTAssertNil(Seed.twoClipsWide.project.heardMusic)

        var noClip = Seed.musicWide.project
        noClip.clips = []
        XCTAssertNotNil(noClip.music)
        XCTAssertNil(noClip.heardMusic)
    }

    func testEachValueOfSoundAloneMakesAnotherFootage() {
        let seed = Seed.musicWide.project
        var changes: [(String, Project)] = []

        var copy = seed
        copy.clipVolume = 0.5
        changes.append(("clipVolume", copy))
        copy = seed
        copy.clipsMuted = true
        changes.append(("clipsMuted", copy))
        copy = seed
        copy.music = nil
        changes.append(("no music", copy))
        copy = seed
        copy.music?.volume = 0.5
        changes.append(("the volume of the music", copy))
        copy = seed
        copy.music?.start = Time(ticks: 600)
        changes.append(("the start", copy))
        copy = seed
        copy.music?.fadeIn = Time(ticks: 300)
        changes.append(("the fade in", copy))
        copy = seed
        copy.music?.fadeOut = Time(ticks: 300)
        changes.append(("the fade out", copy))

        XCTAssertTrue(seed.sameFootage(as: seed))
        for (name, changed) in changes {
            XCTAssertNotEqual(changed, seed, name)
            XCTAssertFalse(seed.sameFootage(as: changed), name)
            XCTAssertFalse(changed.sameFootage(as: seed), name)
        }
    }

    func testProjectsWithMusicThatDifferOnlyInTheirTextsAreTheSameFootage() {
        let seed = Seed.musicWide.project
        var withText = seed
        withText.texts = [textItem(1, "Hello", .whole)]
        withText.nextTextID = 2

        XCTAssertNotEqual(withText, seed)
        XCTAssertTrue(seed.sameFootage(as: withText))
    }
}
