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
        let made = try await twoTonesUnderAMix()
        let file = Self.folder.appendingPathComponent("two-tones.mp4")
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
        for track in sound {
            print("sound track of two-tones.mp4: \(track.coding), \(track.sampleRate) a second, \(track.channels) channels, \(track.duration.seconds) seconds")
        }
        XCTAssertEqual(sound.count, 1, "sound tracks in the file")

        let first = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 1200), to: Time(ticks: 1800))
        let second = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 1200), to: Time(ticks: 1800))
        assertLevel(first, near: 0.5, "440 Hz after the ramp")
        assertLevel(second, near: 0.125, "880 Hz after the ramp")
        let early = try await toneLevel(of: file, hertz: 880, from: .zero, to: Time(ticks: 60))
        let later = try await toneLevel(of: file, hertz: 880, from: Time(ticks: 240), to: Time(ticks: 300))
        XCTAssertLessThan(early, later, "880 Hz in the first tenth of a second and in the fifth")
    }

    /// The same composition and the same mix, read with no export.
    @MainActor
    func testTheSameLevelsComeThroughTheMixWithNoExport() async throws {
        let made = try await twoTonesUnderAMix()
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

    /// The picture of `blue` for 1800 ticks as the product builds it, with two sound tracks of 1800 ticks: 440 Hz
    /// with a peak of 0.5 held at 1, and 880 Hz with a peak of 0.25 that rises from 0 to 0.5 over its first 600 ticks.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avmutableaudiomix
    /// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/setvolume(_:at:)
    /// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/setvolumeramp(fromstartvolume:toendvolume:timerange:)
    @MainActor
    private func twoTonesUnderAMix() async throws
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
        let low = try await writeTone("tone-440", hertz: 440, peak: 0.5, rate: 44100)
        let high = try await writeTone("tone-880", hertz: 880, peak: 0.25, rate: 44100)
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

    /// A QuickTime file with one sound track and no picture, 1800 ticks long: mono, 16 bit, a sine of that pitch
    /// and that peak, written as the clip maker writes the sound of a clip. Keeps a file that is already there.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avassetwriter
    /// https://developer.apple.com/documentation/avfoundation/audio-settings
    /// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
    private func writeTone(_ name: String, hertz: Int, peak: Double, rate: Int) async throws -> URL {
        let file = Self.folder.appendingPathComponent(name + ".mov")
        if FileManager.default.fileExists(atPath: file.path) {
            return file
        }
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)

        let count = 1800 * rate / 600
        var samples = [Int16](repeating: 0, count: count)
        for index in 0..<count {
            let swing = sin(2 * Double.pi * Double(hertz) * Double(index) / Double(rate))
            samples[index] = Int16((peak * 32767 * swing).rounded())
        }
        var format = AudioStreamBasicDescription(
            mSampleRate: Double(rate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2,
            mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var description: CMAudioFormatDescription?
        let described = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &format, layoutSize: 0, layout: nil, magicCookieSize: 0,
            magicCookie: nil, extensions: nil, formatDescriptionOut: &description)
        XCTAssertEqual(described, noErr)
        var block: CMBlockBuffer?
        let allocated = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: count * 2, blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil, offsetToData: 0, dataLength: count * 2, flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block)
        XCTAssertEqual(allocated, kCMBlockBufferNoErr)
        let filled = try XCTUnwrap(block)
        let copied = CMBlockBufferReplaceDataBytes(
            with: samples, blockBuffer: filled, offsetIntoDestination: 0, dataLength: count * 2)
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
            AVNumberOfChannelsKey: 1,
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
