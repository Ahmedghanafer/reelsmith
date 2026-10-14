#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

final class ToneLevelTests: XCTestCase {
    /// One folder for the whole run: the tones, the clip that gives the picture and the exported files.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("tone-level-" + UUID().uuidString)

    /// Two sound tracks under a mix, exported as the product exports: the picture of the clip `blue` through the
    /// product's own video composition, the preset and the file type of `export`.
    @MainActor
    func testTwoSoundTracksUnderAMixExportAsOneTrackAtTheLevelsOfTheMix() async throws {
        let made = try await twoTonesUnderAMix(stereoMusic: false)
        let out = try await exported(made, name: "two-tones.mp4")
        XCTAssertEqual(out.soundTracks, 1, "sound tracks in the file")
        let file = out.file

        let first = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 1200), to: Time(ticks: 1800))
        let second = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 1200), to: Time(ticks: 1800))
        assertLevel(first, near: 0.5, "440 Hz after the ramp")
        assertLevel(second, near: 0.125, "880 Hz after the ramp")
        let early = try await toneLevel(of: file, hertz: 880, from: .zero, to: Time(ticks: 60))
        let later = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 240), to: Time(ticks: 300))
        XCTAssertLessThan(early, later, "880 Hz in the first tenth of a second and in the fifth")
    }

    /// The second tone as music may come from a file: stereo at 48000 samples a second, both channels the same
    /// samples, over the first tone as mono at 44100.
    @MainActor
    func testAStereoToneAt48000OverAMonoToneAt44100ExportsAsOneTrackAtTheLevelsOfTheMix() async throws {
        let made = try await twoTonesUnderAMix(stereoMusic: true)
        let music = try await tracks(of: Self.folder.appendingPathComponent("tone-880-stereo-at-48000.mov")).first
        XCTAssertEqual(music?.sampleRate, 48000)
        XCTAssertEqual(music?.channels, 2)
        let out = try await exported(made, name: "stereo-over-mono.mp4")
        XCTAssertEqual(out.soundTracks, 1, "sound tracks in the file")

        let first = try await toneLevel(of: out.file, hertz: 440, from: Time(ticks: 1200), to: Time(ticks: 1800))
        let second = try await toneLevel(of: out.file, hertz: 880, from: Time(ticks: 1200), to: Time(ticks: 1800))
        assertLevel(first, near: 0.5, "440 Hz after the ramp")
        assertLevel(second, near: 0.125, "880 Hz after the ramp")
    }

    /// The same composition and the same mix, read with no export.
    @MainActor
    func testTheSameLevelsComeThroughTheMixWithNoExport() async throws {
        let made = try await twoTonesUnderAMix(stereoMusic: false)
        let asset = made.composition
        let first = try await mixedToneLevel(
            of: asset, mix: made.mix, hertz: 440, from: Time(ticks: 1200), to: Time(ticks: 1800))
        let second = try await mixedToneLevel(
            of: asset, mix: made.mix, hertz: 880, from: Time(ticks: 1200), to: Time(ticks: 1800))
        assertLevel(first, near: 0.5, "440 Hz after the ramp")
        assertLevel(second, near: 0.125, "880 Hz after the ramp")
        let early = try await mixedToneLevel(of: asset, mix: made.mix, hertz: 880, from: .zero, to: Time(ticks: 60))
        let later = try await mixedToneLevel(
            of: asset, mix: made.mix, hertz: 880, from: Time(ticks: 240), to: Time(ticks: 300))
        XCTAssertLessThan(early, later, "880 Hz in the first tenth of a second and in the fifth")
    }

    /// The merged product: blue for 1800 ticks, then red for 2400, both sounding at 440 Hz with a peak of 0.5.
    func testTheExportOfTwoClipsReads440HertzInsideBothClipsAndNo880() async throws {
        let plan = try renderPlan(for: Seed.twoClips.project)
        let file = try await ExportTests.exported(
            plan, clips: Seed.twoClips.testClips, name: "two-clips-level.out").file
        let windows: [(Time, Time, String)] = [
            (Time(ticks: 600), Time(ticks: 1200), "inside blue"), (Time(ticks: 2400), Time(ticks: 3000), "inside red"),
        ]
        for (start, end, what) in windows {
            let own = try await toneLevel(of: file, hertz: 440, from: start, to: end)
            let other = try await toneLevel(of: file, hertz: 880, from: start, to: end)
            assertLevel(own, near: 0.5, "440 Hz " + what)
            XCTAssertLessThan(other, 0.02, "880 Hz " + what)
        }
    }

    func testASineWithAPeakOfHalfReadsHalfAtItsOwnPitchAndNothingAtAnother() async throws {
        let file = try await writeTone("tone-440", hertz: 440, peak: 0.5, rate: 44100, channels: 1)
        let own = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let other = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(own, near: 0.5, "440 Hz in a tone of 440 Hz")
        XCTAssertLessThan(other, 0.02, "880 Hz in a tone of 440 Hz")
    }

    func testAToneAt48000SamplesASecondReadsTheSameAsOneAt44100() async throws {
        let slow = try await writeTone("tone-440", hertz: 440, peak: 0.5, rate: 44100, channels: 1)
        let fast = try await writeTone("tone-440-at-48000", hertz: 440, peak: 0.5, rate: 48000, channels: 1)
        let rate = try await tracks(of: fast).first?.sampleRate
        XCTAssertEqual(rate, 48000)
        let atSlow = try await toneLevel(of: slow, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let atFast = try await toneLevel(of: fast, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        assertLevel(atFast, near: 0.5, "440 Hz at 48000 samples a second")
        assertLevel(atFast, near: atSlow, "440 Hz at 48000 samples a second against 44100")
    }

    func testATrackOfSilenceReadsBelowTheFloorAtEveryPitchTried() async throws {
        let file = try await writeTone("silence", hertz: 440, peak: 0, rate: 44100, channels: 1)
        for hertz in [440, 880, 1320] {
            let level = try await toneLevel(of: file, hertz: hertz, from: Time(ticks: 600), to: Time(ticks: 1200))
            XCTAssertLessThan(level, 0.02, "\(hertz) Hz in silence")
        }
    }

    /// A window that reaches past the end of the track has samples for a part of itself only.
    func testAWindowThatTheTrackDoesNotFillFailsTheRead() async throws {
        let file = try await writeTone("tone-440", hertz: 440, peak: 0.5, rate: 44100, channels: 1)
        do {
            let level = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 1500), to: Time(ticks: 2100))
            XCTFail("no error, the level reads \(level)")
        } catch {
            let words = (error as? SoundReadingError)?.description
            XCTAssertEqual(words, "the window holds 22050 samples of the 44100 it is long")
        }
    }

    /// Exports as `export` does, with the mix given to the session, and prints what the sound tracks of the file are.
    /// https://developer.apple.com/documentation/avfoundation/avassetexportsession/audiomix
    @MainActor
    private func exported(
        _ made: (composition: AVMutableComposition, videoComposition: AVVideoComposition, mix: AVAudioMix), name: String
    ) async throws -> (file: URL, soundTracks: Int) {
        let file = Self.folder.appendingPathComponent(name)
        let session = try XCTUnwrap(
            AVAssetExportSession(asset: made.composition, presetName: AVAssetExportPresetHighestQuality))
        session.videoComposition = made.videoComposition
        session.audioMix = made.mix
        session.outputFileType = .mp4
        session.outputURL = file
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                done.resume()
            }
        }
        XCTAssertEqual(session.status, .completed, "\(String(describing: session.error))")

        let sound = try await tracks(of: file).filter { $0.kind == "soun" }
        print("sound tracks of \(name): \(sound.count)")
        for track in sound {
            print("sound track of \(name): \(track.coding), \(track.sampleRate) a second, \(track.channels) channels, \(track.duration.seconds) seconds")
        }
        return (file, sound.count)
    }

    /// The picture of `blue` for 1800 ticks as the product builds it, with two sound tracks of 1800 ticks: 440 Hz
    /// with a peak of 0.5 held at 1, and 880 Hz with a peak of 0.25 that rises from 0 to 0.5 over its first 600 ticks.
    /// Both tones are mono at 44100 samples a second, or the second is stereo at 48000.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avmutableaudiomix
    /// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/setvolume(_:at:)
    /// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/setvolumeramp(fromstartvolume:toendvolume:timerange:)
    @MainActor
    private func twoTonesUnderAMix(stereoMusic: Bool) async throws
        -> (composition: AVMutableComposition, videoComposition: AVVideoComposition, mix: AVAudioMix) {
        let clip = TestClip.blue
        _ = try await writeTestClip(clip, to: Self.folder)
        let plan = RenderPlan(
            segments: [
                Segment(
                    clip: ClipID(1), media: clip.info.id, sourceStart: .zero, timelineStart: .zero,
                    duration: Time(ticks: 1800),
                    placement: Placement(quarterTurns: 0, x: 0, y: 656.25, width: 1080, height: 607.5),
                    hasSound: false),
            ],
            duration: Time(ticks: 1800))
        let item = try await makePlayerItem(plan: plan, media: [clip.info.id: clip.info], mediaFolder: Self.folder)
        let composition = try XCTUnwrap(item.asset.mutableCopy() as? AVMutableComposition)
        let videoComposition = try XCTUnwrap(item.videoComposition)

        let whole = CMTimeRange(start: .zero, duration: CMTime(value: 1800, timescale: 600))
        var soundTracks: [AVMutableCompositionTrack] = []
        let low = try await writeTone("tone-440", hertz: 440, peak: 0.5, rate: 44100, channels: 1)
        let high: URL
        if stereoMusic {
            high = try await writeTone("tone-880-stereo-at-48000", hertz: 880, peak: 0.25, rate: 48000, channels: 2)
        } else {
            high = try await writeTone("tone-880", hertz: 880, peak: 0.25, rate: 44100, channels: 1)
        }
        for tone in [low, high] {
            let asset = AVURLAsset(url: tone)
            let source = try await asset.loadTracks(withMediaType: .audio)
            let sourceSound = try XCTUnwrap(source.first)
            let track = try XCTUnwrap(composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
            try track.insertTimeRange(whole, of: sourceSound, at: .zero)
            soundTracks.append(track)
            withExtendedLifetime(asset) {}
        }

        let held = AVMutableAudioMixInputParameters()
        held.trackID = soundTracks[0].trackID
        held.setVolume(1, at: .zero)
        let rising = AVMutableAudioMixInputParameters()
        rising.trackID = soundTracks[1].trackID
        rising.setVolumeRamp(
            fromStartVolume: 0, toEndVolume: 0.5,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 600, timescale: 600)))
        let mix = AVMutableAudioMix()
        mix.inputParameters = [held, rising]
        return (composition, videoComposition, mix)
    }

    /// A QuickTime file with one sound track and no picture, 1800 ticks long: 16 bit, a sine of that pitch and that
    /// peak, the same samples in every channel, written as the clip maker writes the sound of a clip. Keeps a file
    /// that is already there.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avassetwriter
    /// https://developer.apple.com/documentation/avfoundation/audio-settings
    /// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
    private func writeTone(_ name: String, hertz: Int, peak: Double, rate: Int, channels: Int) async throws -> URL {
        let file = Self.folder.appendingPathComponent(name + ".mov")
        if FileManager.default.fileExists(atPath: file.path) {
            return file
        }
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)

        let count = 1800 * rate / 600
        var samples = [Int16](repeating: 0, count: count * channels)
        for index in 0..<count {
            let swing = sin(2 * Double.pi * Double(hertz) * Double(index) / Double(rate))
            for channel in 0..<channels {
                samples[index * channels + channel] = Int16((peak * 32767 * swing).rounded())
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

        let writer = try AVAssetWriter(outputURL: file, fileType: .mov)
        writer.movieTimeScale = 600
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
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
        return file
    }
}

/// A level matches within 15 percent of its expected value.
private func assertLevel(
    _ level: Double, near expected: Double, _ what: String, file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertLessThanOrEqual(
        abs(level - expected), 0.15 * expected, what + " reads \(level), expected \(expected)", file: file, line: line)
}
#endif
