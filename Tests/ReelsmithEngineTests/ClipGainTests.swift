#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// A clip above full volume on `two-clips-wide`, read by pitch in exported files and through the mix of a player
/// item, a reader that stands in for the player. The clips sound at 440 Hz with a peak of 0.5, but for a quiet and a
/// loud red that the tests of the limiter make in folders of their own, with the same picture. Blue is read from
/// 300 to 1500 ticks and red from 2100 to 3900, so no window holds the join at 1800. Each read prints a line that
/// starts with `clip gain:`. The readers of levels and of the largest sample decode to 16 bit, so that largest sample
/// is a print and never past full scale. Red at 3 and the loud red are read as 32 bit float, where a sample past
/// full scale reads past 1.
///
/// https://developer.apple.com/documentation/avfoundation/avassetreaderaudiomixoutput
/// https://developer.apple.com/documentation/avfoundation/avaudiomixinputparameters/getvolumeramp(for:startvolume:endvolume:timerange:)
/// https://developer.apple.com/documentation/avfoundation/avaudiomixinputparameters/audiotapprocessor
final class ClipGainTests: XCTestCase {
    // E23 and the doubling: with the clips at 0.5, red at 2 reads twice red at 1, in the file and through the mix,
    // and blue reads as before.
    @MainActor
    func testWithTheClipsAtHalfRedAtTwoReadsTwiceRedAtOneInTheFileAndThroughTheMix() async throws {
        var project = Seed.twoClipsWide.project
        project.clipVolume = 0.5
        let one = try await reads(try renderPlan(for: project), name: "gain-clips-half-red-one")
        project.clips[1].volume = 2
        let two = try await reads(try renderPlan(for: project), name: "gain-clips-half-red-two")
        print("clip gain: with the clips at 0.5 red at 2 reads \(two.red / one.red) of red at 1 in the file and \(two.mixedRed / one.mixedRed) through the mix")
        assertLevel(two.red, near: 2 * one.red, "red at 2 in the file")
        assertLevel(two.mixedRed, near: 2 * one.mixedRed, "red at 2 through the mix")
        assertLevel(two.blue, near: one.blue, "blue in the file")
        assertLevel(two.mixedBlue, near: one.mixedBlue, "blue through the mix")
    }

    // E23 past full scale: with the clips at 1, red at 2 and red's segment at 3 in a plan built here read above red
    // at 1, so no sign turned over. The levels and the largest samples are prints.
    @MainActor
    func testWithTheClipsAtOneRedAtTwoAndAtThreeReadsAboveRedAtOne() async throws {
        var project = Seed.twoClipsWide.project
        let one = try await reads(try renderPlan(for: project), name: "gain-red-one")
        project.clips[1].volume = 2
        _ = try await reads(try renderPlan(for: project), name: "gain-red-two")
        var plan = try renderPlan(for: Seed.twoClipsWide.project)
        plan.segments[1].volume = 3
        let three = try await reads(plan, name: "gain-red-three")
        XCTAssertGreaterThan(three.red, one.red, "red at 3 in the file above red at 1")
        XCTAssertGreaterThan(three.mixedRed, one.mixedRed, "red at 3 through the mix above red at 1")
    }

    // A level of a clip above 1 is a refresh of the mix: the item takes red at 2, then at 0.5, with no throw. The
    // clip track holds red at 1, then at 0.5, and carries the tap, and through the mix red at 2 reads four times
    // red at 0.5.
    @MainActor
    func testAnItemGivenRedAtTwoThenAtHalfHoldsTheValuesOfTheWay() async throws {
        let item = try await self.item(of: try renderPlan(for: Seed.twoClipsWide.project))
        var project = Seed.twoClipsWide.project
        let tracks = try XCTUnwrap(item.asset as? AVComposition).tracks
            .filter { $0.mediaType == .audio }.map { $0.trackID }
        XCTAssertEqual(tracks.count, 1, "the clip track alone")
        let clips = try XCTUnwrap(tracks.first)

        project.clips[1].volume = 2
        try refreshSound(of: item, plan: try renderPlan(for: project))
        XCTAssertEqual(try volume(of: item, track: clips, at: redAt), 1, accuracy: 0.001, "red at 2 on the clip track")
        XCTAssertNotNil(item.audioMix?.inputParameters.first?.audioTapProcessor, "the tap with red at 2")
        let two = try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: redStart, to: redEnd)

        project.clips[1].volume = 0.5
        try refreshSound(of: item, plan: try renderPlan(for: project))
        XCTAssertEqual(try volume(of: item, track: clips, at: redAt), 0.5, accuracy: 0.001, "red at 0.5 on the clip track")
        XCTAssertNotNil(item.audioMix?.inputParameters.first?.audioTapProcessor, "the tap with red at 0.5")
        let half = try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: redStart, to: redEnd)
        print("clip gain: the refreshed item reads red at 2 at \(two) and at 0.5 at \(half) through the mix")
        assertLevel(two, near: 4 * half, "red at 2 against red at 0.5 through the mix")
    }

    // A refresh keeps the tap the item has, since the player prepares its item again when the tap changes (QA of
    // run 38715394801), and that same tap reads the new gain: with the clips at 0.5, red at 1 then at 2 reads twice.
    @MainActor
    func testARefreshKeepsTheTapOfTheItemAndTheLevelFollowsTheNewGain() async throws {
        var project = Seed.twoClipsWide.project
        project.clipVolume = 0.5
        let item = try await self.item(of: try renderPlan(for: project))
        let before = try XCTUnwrap(item.audioMix?.inputParameters.first?.audioTapProcessor, "no tap after the build")
        let one = try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: redStart, to: redEnd)

        project.clips[1].volume = 2
        try refreshSound(of: item, plan: try renderPlan(for: project))
        let after = try XCTUnwrap(item.audioMix?.inputParameters.first?.audioTapProcessor, "no tap after the refresh")
        XCTAssertTrue(after === before, "the refresh gave the clip track another tap")
        let two = try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: redStart, to: redEnd)
        print("clip gain: the kept tap reads red at 1 at \(one) and at 2 at \(two) through the mix")
        assertLevel(two, near: 2 * one, "red at 2 against red at 1 through the mix, the tap kept")
    }

    // The limiter leaves a quiet clip alone: a red made in the test with a peak of 0.125, the clips at 1, at 1 and
    // at 2, where the tap's gain is 2 and the raised peak of 0.25 lies under the knee. Red reads its plain level
    // within 2 percent, 0.125 at 1 and 0.25 at 2, in the file and through the mix.
    @MainActor
    func testAQuietRedAtOneAndAtTwoReadsItsPlainLevelWithinTwoPercent() async throws {
        var project = Seed.twoClipsWide.project
        let folder = try await clipsWithRed(peak: 0.125)
        let one = try await redReads(try renderPlan(for: project), in: folder, name: "limiter-quiet-red-one")
        project.clips[1].volume = 2
        let two = try await redReads(try renderPlan(for: project), in: folder, name: "limiter-quiet-red-two")
        print("clip gain: a quiet red reads \(one.red) at 1 and \(two.red) at 2 in the file, \(one.mixedRed) and \(two.mixedRed) through the mix")
        assertLevel(one.red, within: 0.02, of: 0.125, "quiet red at 1 in the file")
        assertLevel(one.mixedRed, within: 0.02, of: 0.125, "quiet red at 1 through the mix")
        assertLevel(two.red, within: 0.02, of: 0.25, "quiet red at 2 in the file")
        assertLevel(two.mixedRed, within: 0.02, of: 0.25, "quiet red at 2 through the mix")
    }

    // Red at 3 in a plan built here, a peak of 1.5 before the limiter: in red's window, read as float samples, no
    // sample lies above full scale and fewer than 1 in 1000 lie at it, in the file and through the mix. The largest
    // sample and that share are printed.
    @MainActor
    func testRedAtThreeHasNoSampleAboveFullScaleAndAlmostNoneAtIt() async throws {
        var plan = try renderPlan(for: Seed.twoClipsWide.project)
        plan.segments[1].volume = 3
        let file = try await ExportTests.exported(plan, clips: [.blue, .red], name: "limiter-red-three.out").file
        let item = try await self.item(of: plan)
        try await assertUnderFullScale(file: file, item: item, "red at 3")
    }

    // A loud red made in the test with a peak of 0.98, at 150 and at 200 percent: its own peaks go through the
    // curve too, so no sample lies above full scale and fewer than 1 in 1000 at it, in the file and through the mix.
    @MainActor
    func testALoudRedAtOneHundredFiftyAndAtTwoHundredHasNoSampleAboveFullScaleAndAlmostNoneAtIt() async throws {
        let folder = try await clipsWithRed(peak: 0.98)
        for volume in [1.5, 2.0] {
            var project = Seed.twoClipsWide.project
            project.clips[1].volume = volume
            let plan = try renderPlan(for: project)
            let name = "limiter-loud-red-\(Int(volume * 100))"
            let read = try await redReads(plan, in: folder, name: name)
            print("clip gain: a loud red at \(volume) reads \(read.red) in the file and \(read.mixedRed) through the mix")
            try await assertUnderFullScale(file: read.file, item: read.item, "loud red at \(volume)")
        }
    }

    /// What one plan reads over blue and red, in its exported file and through the mix of its player item, printed
    /// with the largest sample of red's window in each.
    struct Reads {
        var blue: Double
        var red: Double
        var mixedBlue: Double
        var mixedRed: Double
    }

    @MainActor
    private func reads(_ plan: RenderPlan, name: String) async throws -> Reads {
        let file = try await ExportTests.exported(plan, clips: [.blue, .red], name: name + ".out").file
        let item = try await self.item(of: plan)
        let fileAsset = AVURLAsset(url: file)
        let read = Reads(
            blue: try await toneLevel(of: file, hertz: 440, from: blueStart, to: blueEnd),
            red: try await toneLevel(of: file, hertz: 440, from: redStart, to: redEnd),
            mixedBlue: try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: blueStart, to: blueEnd),
            mixedRed: try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: redStart, to: redEnd))
        let largest = try await largestSample(of: fileAsset, mix: nil)
        let mixedLargest = try await largestSample(of: item.asset, mix: item.audioMix)
        print("clip gain: " + name + ": red reads \(read.red) in the file and \(read.mixedRed) through the mix, blue \(read.blue) and \(read.mixedBlue), the largest sample of red \(largest) in the file and \(mixedLargest) through the mix")
        return read
    }

    /// The player item of the plan, with blue and red written first.
    @MainActor
    private func item(of plan: RenderPlan) async throws -> AVPlayerItem {
        for clip in [TestClip.blue, TestClip.red] {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        return try await makePlayerItem(
            plan: plan, media: Seed.twoClipsWide.project.media, mediaFolder: ExportTests.folder)
    }

    /// Red's level in the exported file of a plan made with the clips of the folder and through the mix of its
    /// player item, with the file and the item.
    struct RedReads {
        var red: Double
        var mixedRed: Double
        var file: URL
        var item: AVPlayerItem
    }

    @MainActor
    private func redReads(_ plan: RenderPlan, in folder: URL, name: String) async throws -> RedReads {
        let media = Seed.twoClipsWide.project.media
        let output = folder.appendingPathComponent(name + ".out")
        try? FileManager.default.removeItem(at: output)
        try await export(plan: plan, media: media, mediaFolder: folder, to: output) { _ in }
        // The platform picks its file reader by the end of the name, so the readers read a copy named as MPEG-4.
        let file = folder.appendingPathComponent(name + ".out.mp4")
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.copyItem(at: output, to: file)
        let item = try await makePlayerItem(plan: plan, media: media, mediaFolder: folder)
        return RedReads(
            red: try await toneLevel(of: file, hertz: 440, from: redStart, to: redEnd),
            mixedRed: try await mixedToneLevel(of: item.asset, mix: item.audioMix, hertz: 440, from: redStart, to: redEnd),
            file: file, item: item)
    }

    /// A folder of its own with blue as the clip maker writes it, and red with the clip maker's picture and a 440
    /// Hz tone of that peak, mono 16 bit at 44100 samples a second as the clip maker writes its sound. Red is put
    /// together from the picture and the tone without a new encoding. Keeps a red that is already there.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avmutablecomposition
    /// https://developer.apple.com/documentation/avfoundation/avassetexportpresetpassthrough
    /// https://developer.apple.com/documentation/avfoundation/avassetexportsession/exportasynchronously(completionhandler:)
    private func clipsWithRed(peak: Double) async throws -> URL {
        let folder = ExportTests.folder.appendingPathComponent("red-peak-\(peak)")
        _ = try await writeTestClip(.blue, to: folder)
        let red = folder.appendingPathComponent(TestClip.red.name + ".mov")
        if FileManager.default.fileExists(atPath: red.path) {
            return folder
        }
        var silent = TestClip.red
        silent.hasSound = false
        let picture = try await writeTestClip(silent, to: folder.appendingPathComponent("picture"))
        let tone = try await writeTone(
            peak: peak, ticks: TestClip.red.duration.ticks, to: folder.appendingPathComponent("tone.mov"))
        let pictureTracks = try await AVURLAsset(url: picture).loadTracks(withMediaType: .video)
        let soundTracks = try await AVURLAsset(url: tone).loadTracks(withMediaType: .audio)
        let pictureTrack = try XCTUnwrap(pictureTracks.first, "the picture of red has no picture track")
        let soundTrack = try XCTUnwrap(soundTracks.first, "the tone has no sound track")
        let pictureRange = try await pictureTrack.load(.timeRange)
        let soundRange = try await soundTrack.load(.timeRange)
        let composition = AVMutableComposition()
        let pictureInput = try XCTUnwrap(
            composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        try pictureInput.insertTimeRange(pictureRange, of: pictureTrack, at: .zero)
        let soundInput = try XCTUnwrap(
            composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
        try soundInput.insertTimeRange(soundRange, of: soundTrack, at: .zero)
        let session = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        session.outputFileType = .mov
        session.outputURL = red
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                done.resume()
            }
        }
        XCTAssertEqual(session.status, .completed, "red with a peak of \(peak): \(String(describing: session.error))")
        return folder
    }

    /// In red's window of the file and through the mix of the item, read as float samples: no sample above full
    /// scale and fewer than 1 in 1000 at it. The largest sample and that share are printed.
    @MainActor
    private func assertUnderFullScale(
        file: URL, item: AVPlayerItem, _ what: String, line: UInt = #line
    ) async throws {
        let fileSamples = try await floatSamples(of: AVURLAsset(url: file), mix: nil)
        let mixedSamples = try await floatSamples(of: item.asset, mix: item.audioMix)
        for (place, samples) in [("the file", fileSamples), ("the mix", mixedSamples)] {
            XCTAssertFalse(samples.isEmpty, "no sample of " + what + " in " + place, line: line)
            let largest = samples.map { abs($0) }.max() ?? 0
            let share = Double(samples.filter { abs($0) >= 1 }.count) / Double(max(samples.count, 1))
            print("clip gain: \(what) in \(place): the largest sample \(largest), at full scale \(share) of \(samples.count)")
            XCTAssertLessThanOrEqual(largest, 1, "a sample of " + what + " above full scale in " + place, line: line)
            XCTAssertLessThan(share, 0.001, "the share of " + what + " at full scale in " + place, line: line)
        }
    }

    /// The volume the mix of the item holds for the track at the time, where it stands still.
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
        print("clip gain: track \(track) at \(time.ticks) ticks: found \(found), from \(start) to \(end)")
        XCTAssertTrue(found, "no ramp of track \(track) at \(time.ticks) ticks")
        XCTAssertEqual(start, end, accuracy: 0.001, "a ramp that changes at \(time.ticks) ticks")
        return start
    }
}

private let blueStart = Time(ticks: 300)
private let blueEnd = Time(ticks: 1500)
private let redStart = Time(ticks: 2100)
private let redEnd = Time(ticks: 3900)
private let redAt = Time(ticks: 2400)

/// A level matches within 15 percent of its expected value.
private func assertLevel(
    _ level: Double, near expected: Double, _ what: String, file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertLessThanOrEqual(
        abs(level - expected), 0.15 * expected, what + " reads \(level), expected \(expected)", file: file, line: line)
}

/// A level matches within a share of its expected value.
private func assertLevel(
    _ level: Double, within share: Double, of expected: Double, _ what: String,
    file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertLessThanOrEqual(
        abs(level - expected), share * expected, what + " reads \(level), expected \(expected)", file: file, line: line)
}

/// The samples of the first channel over red's window, all sound tracks of the asset mixed with the mix, decoded
/// to 32 bit float, so a sample past full scale reads past 1.
///
/// https://developer.apple.com/documentation/avfoundation/avassetreaderaudiomixoutput
/// https://developer.apple.com/documentation/coremedia/cmblockbuffercopydatabytes(_:atoffset:datalength:destination:)
private func floatSamples(of asset: AVAsset, mix: AVAudioMix?) async throws -> [Float] {
    let soundTracks = try await asset.loadTracks(withMediaType: .audio)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderAudioMixOutput(audioTracks: soundTracks, audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ])
    output.audioMix = mix
    reader.timeRange = CMTimeRange(
        start: CMTime(value: redStart.ticks, timescale: 600),
        duration: CMTime(value: redEnd.ticks - redStart.ticks, timescale: 600))
    reader.add(output)
    XCTAssertTrue(reader.startReading(), "the reader of the float samples did not start")
    var first: [Float] = []
    while let buffer = output.copyNextSampleBuffer() {
        guard let block = CMSampleBufferGetDataBuffer(buffer),
              let format = CMSampleBufferGetFormatDescription(buffer),
              let basic = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else { continue }
        let channels = max(Int(basic.pointee.mChannelsPerFrame), 1)
        var samples = [Float](repeating: 0, count: CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size)
        _ = samples.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
        }
        for frame in 0..<(samples.count / channels) {
            first.append(samples[frame * channels])
        }
    }
    return first
}

/// The largest size of a sample of the first channel over red's window, all sound tracks of the asset mixed with
/// the mix, decoded to 16 bit: from 0 to 1 of full scale.
///
/// https://developer.apple.com/documentation/avfoundation/avassetreader/timerange
/// https://developer.apple.com/documentation/coremedia/cmblockbuffercopydatabytes(_:atoffset:datalength:destination:)
private func largestSample(of asset: AVAsset, mix: AVAudioMix?) async throws -> Double {
    let soundTracks = try await asset.loadTracks(withMediaType: .audio)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderAudioMixOutput(audioTracks: soundTracks, audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ])
    output.audioMix = mix
    reader.timeRange = CMTimeRange(
        start: CMTime(value: redStart.ticks, timescale: 600),
        duration: CMTime(value: redEnd.ticks - redStart.ticks, timescale: 600))
    reader.add(output)
    XCTAssertTrue(reader.startReading(), "the reader of the largest sample did not start")
    var largest = 0
    while let buffer = output.copyNextSampleBuffer() {
        guard let block = CMSampleBufferGetDataBuffer(buffer),
              let format = CMSampleBufferGetFormatDescription(buffer),
              let basic = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else { continue }
        let channels = max(Int(basic.pointee.mChannelsPerFrame), 1)
        var samples = [Int16](repeating: 0, count: CMBlockBufferGetDataLength(block) / 2)
        _ = samples.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
        }
        for frame in 0..<(samples.count / channels) {
            largest = max(largest, abs(Int(samples[frame * channels])))
        }
    }
    return Double(largest) / 32768
}

/// A QuickTime file with one sound track and no picture, that many ticks long: mono, 16 bit, 44100 samples a second,
/// a 440 Hz sine of that peak, as `ToneLevelTests` writes its tones. Keeps a file that is already there.
///
/// https://developer.apple.com/documentation/avfoundation/avassetwriter
/// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
private func writeTone(peak: Double, ticks: Int64, to file: URL) async throws -> URL {
    if FileManager.default.fileExists(atPath: file.path) {
        return file
    }
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let rate = 44100
    let count = Int(ticks) * rate / 600
    var samples = [Int16](repeating: 0, count: count)
    for index in 0..<count {
        samples[index] = Int16((peak * 32767 * sin(2 * Double.pi * 440 * Double(index) / Double(rate))).rounded())
    }
    let bytes = count * 2
    var format = AudioStreamBasicDescription(
        mSampleRate: Double(rate), mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
        mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
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
    writer.endSession(atSourceTime: CMTime(value: ticks, timescale: 600))
    await writer.finishWriting()
    guard writer.status == .completed else { throw try XCTUnwrap(writer.error) }
    return file
}
#endif
