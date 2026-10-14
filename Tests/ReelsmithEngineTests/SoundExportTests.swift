#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The music and the volumes of a plan, read by pitch from exported files and from player items through their mix.
/// The clips sound at 440 Hz with a peak of 0.5. The long tone sounds at 880 Hz up to 3000 ticks of its file and at
/// 1320 Hz after, the short tone at 660 Hz, both with a peak of 0.25. Every plan is made by `renderPlan(for:)`.
final class SoundExportTests: XCTestCase {
    /// The export of the seed `music-wide` as it is, made once for the tests that read it.
    static let musicWide = Task<URL, Error> {
        try await SoundExportTests.exported(Seed.musicWide.project, tones: [.long], name: "music-wide.out")
    }

    /// Writes the tones, then exports the plan of the project with the clips of `music-wide` through
    /// `ExportTests.exported`, in its folder, and gives the copy named as MPEG-4.
    static func exported(_ project: Project, clips: [TestClip] = Seed.musicWide.testClips, tones: [TestTone],
                         name: String) async throws -> URL {
        for tone in tones {
            _ = try await writeTestTone(tone, to: ExportTests.folder)
        }
        return try await ExportTests.exported(try renderPlan(for: project), clips: clips, name: name).file
    }

    // 1. The seed as it is.
    func testMusicWideReadsTheClipsAt440AndTheMusicAt880BetweenAHalfAndTwoSeconds() async throws {
        let file = try await Self.musicWide.value
        let clips = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(clips, near: 0.5, "440 Hz")
        assertLevel(music, near: 0.25, "880 Hz")
    }

    // 2. The music at a volume of 0.5.
    func testTheMusicAtHalfReads880AtAnEighthAndTheClipsAsBefore() async throws {
        var project = Seed.musicWide.project
        project.music?.volume = 0.5
        let file = try await Self.exported(project, tones: [.long], name: "music-half.out")
        let clips = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(clips, near: 0.5, "440 Hz")
        assertLevel(music, near: 0.125, "880 Hz")
    }

    // 3. The clips at a volume of 0.5, then muted.
    func testTheClipsAtHalfRead440AtAQuarterAndTheMusicAsBefore() async throws {
        var project = Seed.musicWide.project
        project.clipVolume = 0.5
        let file = try await Self.exported(project, tones: [.long], name: "clips-half.out")
        let clips = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(clips, near: 0.25, "440 Hz")
        assertLevel(music, near: 0.25, "880 Hz")
    }

    func testTheClipsMutedAreSilentAndTheMusicAsBefore() async throws {
        var project = Seed.musicWide.project
        project.clipsMuted = true
        let file = try await Self.exported(project, tones: [.long], name: "clips-muted.out")
        let clips = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        XCTAssertLessThan(clips, 0.02, "440 Hz")
        assertLevel(music, near: 0.25, "880 Hz")
    }

    // 4. A start of 3000 ticks in the file: the music begins in the half that sounds at 1320 Hz.
    func testAStartOf3000TicksBeginsTheMusicAt1320() async throws {
        var project = Seed.musicWide.project
        project.music?.start = Time(ticks: 3000)
        let file = try await Self.exported(project, tones: [.long], name: "music-start.out")
        let later = try await toneLevel(of: file, hertz: 1320, from: .zero, to: Time(ticks: 600))
        let earlier = try await toneLevel(of: file, hertz: 880, from: .zero, to: Time(ticks: 600))
        assertLevel(later, near: 0.25, "1320 Hz")
        XCTAssertLessThan(earlier, 0.02, "880 Hz")
    }

    // 5. A fade in of 600 ticks, read on the exported file.
    func testAFadeInOf600TicksRisesFromNothingToTheLevelOfTheMusic() async throws {
        var project = Seed.musicWide.project
        project.music?.fadeIn = Time(ticks: 600)
        let file = try await Self.exported(project, tones: [.long], name: "fade-in.out")
        let first = try await toneLevel(of: file, hertz: 880, from: .zero, to: Time(ticks: 60))
        let fifth = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 240), to: Time(ticks: 300))
        let twelfth = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 660), to: Time(ticks: 720))
        XCTAssertLessThan(first, 0.05, "880 Hz in the first tenth of a second")
        XCTAssertGreaterThan(fifth, 0.0625, "880 Hz in the fifth tenth of a second")
        XCTAssertLessThan(fifth, 0.1875, "880 Hz in the fifth tenth of a second")
        assertLevel(twelfth, near: 0.25, "880 Hz in the twelfth tenth of a second")
    }

    // 6. A fade out of 600 ticks at the end of the music, which is heard for 4200 ticks and sounds at 1320 Hz there.
    func testAFadeOutOf600TicksFallsFromTheLevelOfTheMusicToNothingAtItsEnd() async throws {
        var project = Seed.musicWide.project
        project.music?.fadeOut = Time(ticks: 600)
        let file = try await Self.exported(project, tones: [.long], name: "fade-out.out")
        let last = try await toneLevel(of: file, hertz: 1320, from: Time(ticks: 4140), to: Time(ticks: 4200))
        let middle = try await toneLevel(of: file, hertz: 1320, from: Time(ticks: 3900), to: Time(ticks: 3960))
        let before = try await toneLevel(of: file, hertz: 1320, from: Time(ticks: 3480), to: Time(ticks: 3540))
        XCTAssertLessThan(last, 0.05, "1320 Hz in the last tenth of a second")
        XCTAssertGreaterThan(middle, 0.0625, "1320 Hz in the fifth tenth of a second before the end")
        XCTAssertLessThan(middle, 0.1875, "1320 Hz in the fifth tenth of a second before the end")
        assertLevel(before, near: 0.25, "1320 Hz before the fade")
    }

    // 7. The short tone with a fade out, so the music ends before the video and the clips go on alone.
    func testAShortMusicFadesOutWhereItEndsAndTheClipsGoOnAlone() async throws {
        var project = Seed.musicWide.project
        project.music = Music(file: TestTone.short.file, start: .zero, volume: 1, fadeIn: .zero, fadeOut: Time(ticks: 600))
        let file = try await Self.exported(project, tones: [.short], name: "short-music.out")
        let held = try await toneLevel(of: file, hertz: 660, from: Time(ticks: 480), to: Time(ticks: 540))
        let last = try await toneLevel(of: file, hertz: 660, from: Time(ticks: 1140), to: Time(ticks: 1200))
        let after = try await toneLevel(of: file, hertz: 660, from: Time(ticks: 1260), to: Time(ticks: 1860))
        let clips = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 1260), to: Time(ticks: 1860))
        assertLevel(held, near: 0.25, "660 Hz before the fade")
        XCTAssertLessThan(last, 0.05, "660 Hz in the last tenth of a second of the music")
        XCTAssertLessThan(after, 0.02, "660 Hz after the music")
        assertLevel(clips, near: 0.5, "440 Hz after the music")
    }

    // 8. One sound track in the file, with the clips and with a clip that has no sound.
    func testMusicWideHasOneSoundTrackOf4200TicksAnd210Frames() async throws {
        let file = try await Self.musicWide.value
        let sound = try await tracks(of: file).filter { $0.kind == "soun" }
        print("sound tracks of music-wide: \(sound.count)")
        XCTAssertEqual(sound.count, 1)
        XCTAssertEqual(
            sound.first?.duration, CMTime(value: 4200, timescale: 600), "\(String(describing: sound.first?.duration.seconds))")
        let count = try await frameCount(of: file)
        XCTAssertEqual(count, 210)
    }

    func testTheClipGreenWithNoSoundAndTheMusicHasOneSoundTrackThatHoldsTheMusic() async throws {
        var project = Project()
        let green = TestClip.green
        project.media[green.info.id] = green.info
        project.clips.append(Clip(id: ClipID(1), media: green.info.id, sourceStart: .zero, duration: green.duration))
        project.nextClipID = 2
        project.music = Music(file: TestTone.long.file)
        let file = try await Self.exported(project, clips: [green], tones: [.long], name: "green-music.out")
        let sound = try await tracks(of: file).filter { $0.kind == "soun" }
        print("sound tracks of green with music: \(sound.count)")
        XCTAssertEqual(sound.count, 1)
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 300), to: Time(ticks: 900))
        assertLevel(music, near: 0.25, "880 Hz inside green")
    }

    // 9. The player item carries the mix, read with no export. No ramp is read this way.
    @MainActor
    func testTheItemReadThroughItsMixGivesTheMusicAtHalf() async throws {
        var project = Seed.musicWide.project
        project.music?.volume = 0.5
        let (item, mix) = try await itemAndMix(of: project)
        let clips = try await mixedToneLevel(
            of: item.asset, mix: mix, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await mixedToneLevel(
            of: item.asset, mix: mix, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(clips, near: 0.5, "440 Hz through the mix")
        assertLevel(music, near: 0.125, "880 Hz through the mix")
    }

    @MainActor
    func testTheItemReadThroughItsMixGivesTheClipsAtHalf() async throws {
        var project = Seed.musicWide.project
        project.clipVolume = 0.5
        let (item, mix) = try await itemAndMix(of: project)
        let clips = try await mixedToneLevel(
            of: item.asset, mix: mix, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await mixedToneLevel(
            of: item.asset, mix: mix, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(clips, near: 0.25, "440 Hz through the mix")
        assertLevel(music, near: 0.25, "880 Hz through the mix")
    }

    @MainActor
    func testTheItemReadThroughItsMixGivesTheClipsMuted() async throws {
        var project = Seed.musicWide.project
        project.clipsMuted = true
        let (item, mix) = try await itemAndMix(of: project)
        let clips = try await mixedToneLevel(
            of: item.asset, mix: mix, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await mixedToneLevel(
            of: item.asset, mix: mix, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        XCTAssertLessThan(clips, 0.02, "440 Hz through the mix")
        assertLevel(music, near: 0.25, "880 Hz through the mix")
    }

    // 10. Stereo AAC music at 48000 samples a second under the mono clips at 44100, at a volume of 0.5 as in the
    // export the four printed numbers come from.
    func testStereoAACMusicAt48000UnderTheMonoClipsReadsAsTheTryOfTheMixPrinted() async throws {
        let name = "aac-tone.m4a"
        try await writeAACTone(to: ExportTests.folder.appendingPathComponent(name))
        let read = try await readMusicFile(id: MediaID("aac-tone"), fileName: name, title: "aac-tone", in: ExportTests.folder)
        print("aac-tone.m4a reads as \(read.duration.ticks) ticks")
        var project = Seed.musicWide.project
        project.music = Music(file: read, start: .zero, volume: 0.5, fadeIn: .zero, fadeOut: .zero)
        let file = try await Self.exported(project, tones: [], name: "aac-music.out")

        let sound = try await tracks(of: file).filter { $0.kind == "soun" }
        for track in sound {
            print("sound track of aac-music: \(track.coding), \(track.sampleRate) a second, \(track.channels) channels")
        }
        XCTAssertEqual(sound.count, 1)
        XCTAssertEqual(sound.first?.sampleRate, printedRate)
        XCTAssertEqual(sound.first?.channels, printedChannels)
        let clips = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let music = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(clips, near: printed440, "440 Hz")
        assertLevel(music, near: printed880, "880 Hz")

        project.music?.start = Time(ticks: 600)
        let started = try await Self.exported(project, tones: [], name: "aac-music-start.out")
        let fromStart = try await toneLevel(of: started, hertz: 880, from: .zero, to: Time(ticks: 600))
        assertLevel(fromStart, near: printed880, "880 Hz with a start of 600 ticks")
    }

    // 11. A music file that is not in the media folder.
    @MainActor
    func testAMissingMusicFileThrowsSourceMissingWithTheIdOfTheLayerFromMakePlayerItem() async throws {
        let (folder, project) = try await clipsWithoutTheirMusic()
        do {
            _ = try await makePlayerItem(
                plan: try renderPlan(for: project), media: project.media, mediaFolder: folder)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .sourceMissing(MediaID("long-tone")))
        }
    }

    func testAMissingMusicFileThrowsSourceMissingWithTheIdOfTheLayerFromExport() async throws {
        let (folder, project) = try await clipsWithoutTheirMusic()
        do {
            try await export(
                plan: try renderPlan(for: project), media: project.media, mediaFolder: folder,
                to: folder.appendingPathComponent("out.mp4")) { _ in }
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .sourceMissing(MediaID("long-tone")))
        }
    }

    // Printed, asserted on nothing: whether two loud sources clip. The clip maker gives the clips a peak of 0.5,
    // so the music here is a tone made in the test with a peak of 0.7, both at a volume of 1.
    func testThePeakOfTwoLoudTonesIsPrinted() async throws {
        let loud = TestTone(
            name: "loud-tone", duration: Time(ticks: 4200), firstHertz: 880, secondHertz: 880, peak: 0.7,
            sampleRate: 44100, channels: 1)
        var project = Seed.musicWide.project
        project.music = Music(file: loud.file)
        let file = try await Self.exported(project, tones: [loud], name: "loud.out")
        let peak = try await soundPeak(of: file)
        print("sound mix: the peak of the clips at 0.5 and a tone at 0.7, both at full volume: \(peak)")
    }

    /// The player item of the plan of the project, the clips and tones of `music-wide` written first, and its mix.
    @MainActor
    private func itemAndMix(of project: Project) async throws -> (AVPlayerItem, AVAudioMix) {
        for clip in Seed.musicWide.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        _ = try await writeTestTone(.long, to: ExportTests.folder)
        let item = try await makePlayerItem(
            plan: try renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
        let mix = try XCTUnwrap(item.audioMix, "the item carries no mix")
        return (item, mix)
    }

    /// A new folder that holds the clips of `music-wide` and not its tone, and the project of that seed.
    private func clipsWithoutTheirMusic() async throws -> (URL, Project) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("sound-mix-" + UUID().uuidString)
        for clip in Seed.musicWide.testClips {
            _ = try await writeTestClip(clip, to: folder)
        }
        return (folder, Seed.musicWide.project)
    }

    /// 880 Hz with a peak of 0.25, stereo at 48000 samples a second, 1800 ticks, as AAC at 128000 bits a second in
    /// an MPEG-4 audio file, given to the writer as 16 bit samples with the same samples in both channels: the way
    /// the try at two formats in `MusicProbeTests` writes it, which the hosted Mac wrote in run 38505807047.
    /// Keeps a file that is already there.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avassetwriter
    /// https://developer.apple.com/documentation/avfoundation/audio-settings
    /// https://developer.apple.com/documentation/avfoundation/avfiletype/m4a
    /// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
    private func writeAACTone(to file: URL) async throws {
        if FileManager.default.fileExists(atPath: file.path) {
            return
        }
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let rate = 48000
        let channels = 2
        let count = 1800 * rate / 600
        var samples = [Int16](repeating: 0, count: count * channels)
        for index in 0..<count {
            let swing = sin(2 * Double.pi * 880 * Double(index) / Double(rate))
            for channel in 0..<channels {
                samples[index * channels + channel] = Int16((0.25 * 32767 * swing).rounded())
            }
        }
        let bytes = count * channels * 2
        var format = AudioStreamBasicDescription(
            mSampleRate: Double(rate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channels * 2), mFramesPerPacket: 1, mBytesPerFrame: UInt32(channels * 2),
            mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 16, mReserved: 0)
        var description: CMAudioFormatDescription?
        let described = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &format, layoutSize: 0, layout: nil, magicCookieSize: 0,
            magicCookie: nil, extensions: nil, formatDescriptionOut: &description)
        XCTAssertEqual(described, noErr)
        var block: CMBlockBuffer?
        let allocated = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes, blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil, offsetToData: 0, dataLength: bytes, flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block)
        XCTAssertEqual(allocated, kCMBlockBufferNoErr)
        let filled = try XCTUnwrap(block)
        let copied = CMBlockBufferReplaceDataBytes(
            with: samples, blockBuffer: filled, offsetIntoDestination: 0, dataLength: bytes)
        XCTAssertEqual(copied, kCMBlockBufferNoErr)
        var made: CMSampleBuffer?
        let wrapped = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault, dataBuffer: filled, formatDescription: try XCTUnwrap(description),
            sampleCount: count, presentationTimeStamp: .zero, packetDescriptions: nil, sampleBufferOut: &made)
        XCTAssertEqual(wrapped, noErr)
        let whole = try XCTUnwrap(made)

        let writer = try AVAssetWriter(outputURL: file, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: 128000,
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        XCTAssertTrue(writer.canAdd(input))
        writer.add(input)
        guard writer.startWriting() else { throw try XCTUnwrap(writer.error) }
        writer.startSession(atSourceTime: .zero)
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw try XCTUnwrap(writer.error) }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        guard input.append(whole) else { throw try XCTUnwrap(writer.error) }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 1800, timescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw try XCTUnwrap(writer.error) }
    }
}

// What the export of a stereo tone at 48000 samples a second under a volume of 0.5, over a mono tone at 44100
// held at 1, printed in compile check run 38501091534 by
// `ToneLevelTests.testAStereoToneAt48000OverAMonoToneAt44100ExportsAsOneTrackAtTheLevelsOfTheMix`: one AAC track
// at 48000 samples a second with 2 channels, the mono tone at 0.49987 and the stereo tone at 0.12483.
private let printedRate = 48000.0
private let printedChannels = 2
private let printed440 = 0.49987
private let printed880 = 0.12483

/// A level matches within 15 percent of its expected value.
private func assertLevel(
    _ level: Double, near expected: Double, _ what: String, file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertLessThanOrEqual(
        abs(level - expected), 0.15 * expected, what + " reads \(level), expected \(expected)", file: file, line: line)
}
#endif
