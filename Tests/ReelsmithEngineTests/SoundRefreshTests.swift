#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// `refreshSound` on player items of `music-wide` and `two-clips-wide`, read from the mix of the item by the volume
/// in effect at a time (`getVolumeRamp`). The clips and the tone are written in the folder of `ExportTests`.
///
/// https://developer.apple.com/documentation/avfoundation/avaudiomixinputparameters/getvolumeramp(for:startvolume:endvolume:timerange:)
final class SoundRefreshTests: XCTestCase {
    @MainActor
    func testAnItemOfMusicWideGivenThePlanWithTheMusicAtAQuarterHasTheMusicAtAQuarterAndTheClipsAtOne() async throws {
        let item = try await self.item(of: Seed.musicWide.project)
        var project = Seed.musicWide.project
        project.music?.volume = 0.25

        try refreshSound(of: item, plan: try renderPlan(for: project))

        let (clips, music) = try soundTracks(of: item)
        let musicVolume = try volume(of: item, track: try XCTUnwrap(music), at: Time(ticks: 600))
        let clipVolume = try volume(of: item, track: try XCTUnwrap(clips), at: Time(ticks: 600))
        print("sound refresh: music-wide with the music at 0.25 reads the music at \(musicVolume) and the clips at \(clipVolume) at 1 second")
        XCTAssertEqual(musicVolume, 0.25, accuracy: 0.001)
        XCTAssertEqual(clipVolume, 1, accuracy: 0.001)
    }

    @MainActor
    func testAnItemOfTwoClipsWideGivenAPlanWithMusicThrowsCannotReadAndKeepsItsMix() async throws {
        let item = try await self.item(of: Seed.twoClipsWide.project)
        var project = Seed.twoClipsWide.project
        project.clips[1].volume = 0.5
        project.music = Music(file: TestTone.long.file)
        let before = item.audioMix?.inputParameters.map { $0.trackID }

        do {
            try refreshSound(of: item, plan: try renderPlan(for: project))
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }

        XCTAssertEqual(item.audioMix?.inputParameters.map { $0.trackID }, before)
        let (clips, _) = try soundTracks(of: item)
        let red = try volume(of: item, track: try XCTUnwrap(clips), at: Time(ticks: 1800))
        print("sound refresh: two-clips-wide after the refused plan reads red at \(red)")
        XCTAssertEqual(red, 1, accuracy: 0.001)
    }

    @MainActor
    func testAnItemOfTwoClipsWideGivenThePlanWithRedAtHalfReadsHalfAtTheStartOfRed() async throws {
        let item = try await self.item(of: Seed.twoClipsWide.project)
        var project = Seed.twoClipsWide.project
        project.clips[1].volume = 0.5

        try refreshSound(of: item, plan: try renderPlan(for: project))

        let (clips, music) = try soundTracks(of: item)
        XCTAssertNil(music)
        let red = try volume(of: item, track: try XCTUnwrap(clips), at: Time(ticks: 1800))
        let blue = try volume(of: item, track: try XCTUnwrap(clips), at: Time(ticks: 600))
        print("sound refresh: two-clips-wide with red at 0.5 reads red at \(red) at its start and blue at \(blue)")
        XCTAssertEqual(red, 0.5, accuracy: 0.001)
        XCTAssertEqual(blue, 1, accuracy: 0.001)
    }

    /// The player item of the project's plan, with the clips of `music-wide` and the long tone written first.
    @MainActor
    private func item(of project: Project) async throws -> AVPlayerItem {
        for clip in Seed.musicWide.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        _ = try await writeTestTone(.long, to: ExportTests.folder)
        return try await makePlayerItem(
            plan: try renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
    }

    /// The ids of the sound tracks of the item's composition: the lower one is the clips, the higher one the music.
    /// With one track only the plan tells which, and these tests give the music only with the clips.
    @MainActor
    private func soundTracks(of item: AVPlayerItem) throws -> (clips: CMPersistentTrackID?, music: CMPersistentTrackID?) {
        let composition = try XCTUnwrap(item.asset as? AVComposition)
        let ids = composition.tracks.filter { $0.mediaType == .audio }.map { $0.trackID }.sorted()
        return (ids.first, ids.count > 1 ? ids.last : nil)
    }

    /// The volume the mix of the item holds for the track at the time: the start of the ramp found there, which is
    /// also its end for a volume that stands still. Fails when the mix has no ramp at that time.
    @MainActor
    private func volume(of item: AVPlayerItem, track: CMPersistentTrackID, at time: Time) throws -> Float {
        let mix = try XCTUnwrap(item.audioMix, "the item carries no mix")
        let parameters = try XCTUnwrap(
            mix.inputParameters.first { $0.trackID == track }, "the mix has no parameters for track \(track)")
        var start: Float = -1
        var end: Float = -1
        var range = CMTimeRange()
        let found = parameters.getVolumeRamp(
            for: CMTime(value: time.ticks, timescale: 600), startVolume: &start, endVolume: &end, timeRange: &range)
        print("sound refresh: track \(track) at \(time.ticks) ticks: found \(found), from \(start) to \(end) over \(range.start.seconds) to \(range.end.seconds) seconds")
        XCTAssertTrue(found, "no ramp of track \(track) at \(time.ticks) ticks")
        XCTAssertEqual(start, end, accuracy: 0.001, "a ramp that changes at \(time.ticks) ticks")
        return start
    }
}
#endif
