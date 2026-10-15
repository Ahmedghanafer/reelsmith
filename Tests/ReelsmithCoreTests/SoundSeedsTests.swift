import ReelsmithCore
import XCTest

final class SoundSeedsTests: XCTestCase {
    func testTheTwoTestTonesHoldTheValuesOfTheTable() {
        XCTAssertEqual(TestTone.long, TestTone(
            name: "long-tone", duration: Time(ticks: 6000), firstHertz: 880, secondHertz: 1320, peak: 0.25,
            sampleRate: 44100, channels: 1))
        XCTAssertEqual(TestTone.short, TestTone(
            name: "short-tone", duration: Time(ticks: 1200), firstHertz: 660, secondHertz: 660, peak: 0.25,
            sampleRate: 44100, channels: 1))
        XCTAssertEqual(TestTone.all, [.long, .short])
    }

    func testTheFileOfATestToneHasTheIdTheFileNameAndTheTitleOfItsName() {
        XCTAssertEqual(TestTone.long.file, MusicFile(
            id: MediaID("long-tone"), fileName: "long-tone.mov", title: "long-tone", duration: Time(ticks: 6000)))
        XCTAssertEqual(TestTone.short.file, MusicFile(
            id: MediaID("short-tone"), fileName: "short-tone.mov", title: "short-tone", duration: Time(ticks: 1200)))
    }

    func testTheMusicSeedIsTheWideSeedWithTheLongToneAsItsMusic() {
        var wanted = Seed.twoClipsWide.project
        wanted.music = Music(file: TestTone.long.file)

        XCTAssertEqual(Seed(rawValue: "music-wide"), .musicWide)
        XCTAssertEqual(Seed.musicWide.project, wanted)
        XCTAssertEqual(Seed.musicWide.canvas, .landscape)
        XCTAssertEqual(Seed.musicWide.testClips, [.blue, .red])
        XCTAssertNil(Seed.musicWide.selectedText)
        XCTAssertEqual(Seed.musicWide.testTones, [.long])
        XCTAssertTrue(Seed.musicWide.showsSound)
    }

    func testTheOtherSevenSeedsHaveNoTestToneAndDoNotShowTheSoundPanel() {
        let others: [Seed] = [.empty, .twoClips, .threeClips, .twoClipsWide, .textWide, .textBoxWide, .photoWide]

        XCTAssertEqual(Set(Seed.allCases), Set(others + [.musicWide]))
        for seed in others {
            XCTAssertEqual(seed.testTones, [], seed.rawValue)
            XCTAssertFalse(seed.showsSound, seed.rawValue)
        }
    }
}
