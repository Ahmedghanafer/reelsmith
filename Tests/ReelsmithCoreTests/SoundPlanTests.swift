import ReelsmithCore
import XCTest

final class SoundPlanTests: XCTestCase {
    private func layer(of project: Project) throws -> MusicLayer {
        try XCTUnwrap(try renderPlan(for: project).sound.music)
    }

    func testThePlanOfAProjectWithNoMusicHasThePlainSound() throws {
        XCTAssertEqual(SoundPlan.plain, SoundPlan(clipVolume: 1, music: nil))
        XCTAssertEqual(try renderPlan(for: Seed.twoClipsWide.project).sound, .plain)
    }

    func testAPlanMadeWithItsFourOlderArgumentsHasThePlainSound() {
        XCTAssertEqual(RenderPlan(segments: [], duration: .zero, canvas: .landscape, texts: []).sound, .plain)
    }

    func testThePlanOfTheMusicSeedCarriesTheLongToneForTheLengthOfTheProject() throws {
        XCTAssertEqual(
            try renderPlan(for: Seed.musicWide.project).sound,
            SoundPlan(
                clipVolume: 1,
                music: MusicLayer(
                    media: MediaID("long-tone"), fileName: "long-tone.mov", sourceStart: .zero,
                    duration: Time(ticks: 4200), volume: 1, fadeIn: .zero, fadeOut: .zero)))
    }

    func testThePlanReadsTheVolumeOfTheClipsAndZeroWhenTheyAreMuted() throws {
        var project = Seed.musicWide.project
        project.clipVolume = 0.5
        XCTAssertEqual(try renderPlan(for: project).sound.clipVolume, 0.5)

        project.clipsMuted = true
        XCTAssertEqual(try renderPlan(for: project).sound.clipVolume, 0)
        XCTAssertEqual(project.clipVolume, 0.5)
    }

    func testThePlanLaysTheMusicFromItsStartForWhatIsHeard() throws {
        var project = Seed.musicWide.project
        project.music?.start = Time(ticks: 3000)
        project.music?.volume = 0.25
        let music = try layer(of: project)

        XCTAssertEqual(music.sourceStart, Time(ticks: 3000))
        XCTAssertEqual(music.duration, Time(ticks: 3000))
        XCTAssertEqual(music.volume, 0.25)
    }

    func testThePlanCutsEachFadeToHalfOfWhatIsHeard() throws {
        var project = Seed.musicWide.project
        project.music?.fadeIn = Time(ticks: 3000)
        project.music?.fadeOut = Time(ticks: 3000)
        let stored = project
        var music = try layer(of: project)

        XCTAssertEqual(music.fadeIn, Time(ticks: 2100))
        XCTAssertEqual(music.fadeOut, Time(ticks: 2100))
        XCTAssertEqual(project, stored)

        project.music?.file = TestTone.short.file
        music = try layer(of: project)
        XCTAssertEqual(music.duration, Time(ticks: 1200))
        XCTAssertEqual(music.fadeIn, Time(ticks: 600))
        XCTAssertEqual(music.fadeOut, Time(ticks: 600))
        XCTAssertEqual(project.music?.fadeIn, Time(ticks: 3000))
        XCTAssertEqual(project.music?.fadeOut, Time(ticks: 3000))
    }

    func testAFadeShorterThanHalfOfWhatIsHeardStaysAsStored() throws {
        var project = Seed.musicWide.project
        project.music?.fadeIn = Time(ticks: 300)
        project.music?.fadeOut = Time(ticks: 300)
        let music = try layer(of: project)

        XCTAssertEqual(music.fadeIn, Time(ticks: 300))
        XCTAssertEqual(music.fadeOut, Time(ticks: 300))
    }

    func testAProjectWithMusicAndNoClipHasNoMusicInItsPlan() throws {
        var project = Seed.musicWide.project
        project.clips = []

        XCTAssertNil(try renderPlan(for: project).sound.music)
    }
}
