#if canImport(AVFoundation)
import AVFoundation
import Foundation
import ReelsmithCore
import XCTest

// musicUse is internal to the Engine: a protected file cannot be made for a test, so its table is read alone.
@testable import ReelsmithEngine

final class MusicProbeTests: XCTestCase {
    /// One folder for the whole run, holding the tones and the clips a test reads from.
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("music-files-" + UUID().uuidString)

    func testTheLongToneReadsAsAMusicFileWithTheIdTheFileNameTheTitleAndItsLength() async throws {
        _ = try await writeTestTone(TestTone.long, to: Self.folder)
        let music = try await readMusicFile(id: MediaID("a"), fileName: "long-tone.mov", title: "Song", in: Self.folder)

        XCTAssertEqual(
            music, MusicFile(id: MediaID("a"), fileName: "long-tone.mov", title: "Song", duration: Time(ticks: 6000)))
    }

    func testAFileNameThatIsNotInTheFolderThrowsSourceMissingWithTheId() async throws {
        let folder = try emptyFolder()
        do {
            _ = try await readMusicFile(id: MediaID("gone"), fileName: "gone.mov", title: "Gone", in: folder)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .sourceMissing(MediaID("gone")))
        }
    }

    func testAVideoWithNoSoundThrowsCannotRead() async throws {
        _ = try await writeTestClip(TestClip.green, to: Self.folder)
        do {
            _ = try await readMusicFile(id: MediaID("green"), fileName: "green.mov", title: "green", in: Self.folder)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
    }

    func testAnImportWithNoTitleCopiesUnderANewIdAndTakesTheNameOfTheSource() async throws {
        let source = try await writeTestTone(TestTone.long, to: Self.folder)
        let media = try emptyFolder().appendingPathComponent("media")

        let music = try await importMusic(from: source, title: nil, to: media)

        let base = String(music.fileName.dropLast(".mov".count))
        XCTAssertNotNil(UUID(uuidString: base), music.fileName)
        XCTAssertEqual(music.fileName, base + ".mov")
        XCTAssertEqual(music.id, MediaID(base))
        XCTAssertEqual(music.title, "long-tone")
        XCTAssertEqual(music.duration, Time(ticks: 6000))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: media.path), [music.fileName])
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testAnImportWithATitleKeepsItScalarForScalar() async throws {
        let source = try await writeTestTone(TestTone.short, to: Self.folder)
        let media = try emptyFolder()
        let title = "\u{623}\u{63A}\u{646}\u{64A}\u{629} \u{627}\u{644}\u{635}\u{64A}\u{641}"

        let music = try await importMusic(from: source, title: title, to: media)

        XCTAssertEqual(Array(music.title.unicodeScalars), Array(title.unicodeScalars))
        XCTAssertEqual(music.duration, Time(ticks: 1200))
    }

    func testATextFileIsRefusedWithCannotReadAndLeavesNothing() async throws {
        let sources = try emptyFolder()
        let notes = sources.appendingPathComponent("notes.txt")
        try Data("not music".utf8).write(to: notes)
        let media = try emptyFolder()

        do {
            _ = try await importMusic(from: notes, title: nil, to: media)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: media.path), [])
    }

    func testASourceThatDoesNotExistIsRefusedWithCannotReadAndLeavesNothing() async throws {
        let missing = try emptyFolder().appendingPathComponent("missing.mov")
        let media = try emptyFolder()

        do {
            _ = try await importMusic(from: missing, title: nil, to: media)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: media.path), [])
    }

    func testAVideoWithSoundIsAcceptedWithTheLengthOfItsSound() async throws {
        let blue = try await writeTestClip(TestClip.blue, to: Self.folder)
        let media = try emptyFolder()

        let music = try await importMusic(from: blue, title: nil, to: media)

        XCTAssertEqual(music.duration, Time(ticks: 1800))
        XCTAssertEqual(music.title, "blue")
    }

    func testTheWholeTableOfMusicUse() {
        // Sound, protected, composable, exportable, and the answer.
        let table: [(Bool, Bool, Bool, Bool, EngineError?)] = [
            (false, false, false, false, .cannotRead),
            (false, false, false, true, .cannotRead),
            (false, false, true, false, .cannotRead),
            (false, false, true, true, .cannotRead),
            (false, true, false, false, .protectedFile),
            (false, true, false, true, .protectedFile),
            (false, true, true, false, .protectedFile),
            (false, true, true, true, .protectedFile),
            (true, false, false, false, .protectedFile),
            (true, false, false, true, .protectedFile),
            (true, false, true, false, .protectedFile),
            (true, false, true, true, nil),
            (true, true, false, false, .protectedFile),
            (true, true, false, true, .protectedFile),
            (true, true, true, false, .protectedFile),
            (true, true, true, true, .protectedFile),
        ]
        for (hasSound, isProtected, isComposable, isExportable, wanted) in table {
            let answer = musicUse(
                hasSound: hasSound, isProtected: isProtected, isComposable: isComposable, isExportable: isExportable)
            XCTAssertEqual(
                answer, wanted,
                "sound \(hasSound), protected \(isProtected), composable \(isComposable), exportable \(isExportable)")
        }
    }

    // The try at two formats: no criterion. What the hosted Mac writes and reads is printed for the record.

    /// 880 Hz with a peak of 0.25, stereo at 48000 samples a second, 1800 ticks, as AAC in an MPEG-4 audio file.
    /// https://developer.apple.com/documentation/avfoundation/avfiletype/m4a
    func testTryAnAACToneInAnMPEG4AudioFile() async throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
        ]
        try await tryFormat(
            name: "aac-tone.m4a", fileType: .m4a, settings: settings, hertz: 880, rate: 48000, channels: 2)
    }

    /// 880 Hz with a peak of 0.25, mono at 44100 samples a second, 1800 ticks, uncompressed 16 bit in a WAVE file.
    /// https://developer.apple.com/documentation/avfoundation/avfiletype/wav
    func testTryAToneInAWaveFile() async throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        try await tryFormat(
            name: "wave-tone.wav", fileType: .wav, settings: settings, hertz: 880, rate: 44100, channels: 1)
    }

    /// Writes the tone, prints its tracks and its level, reads it with readMusicFile and imports it with importMusic,
    /// printing each answer. A file the Mac will not write is printed and skipped. Nothing here fails the test.
    private func tryFormat(
        name: String, fileType: AVFileType, settings: [String: Any], hertz: Int, rate: Int, channels: Int
    ) async throws {
        let folder = try emptyFolder()
        let file = folder.appendingPathComponent(name)
        do {
            try await writeTone(
                to: file, fileType: fileType, settings: settings, hertz: hertz, rate: rate, channels: channels)
        } catch {
            print("try \(name): not written: \(error)")
            throw XCTSkip("the Mac did not write " + name)
        }
        print("try \(name): written")
        for track in (try? await tracks(of: file)) ?? [] {
            print("try \(name): track \(track.kind) \(track.coding), \(track.sampleRate) a second, \(track.channels) channels, \(track.duration.seconds) seconds")
        }
        do {
            _ = try await toneLevel(of: file, hertz: hertz, from: Time(ticks: 600), to: Time(ticks: 1200))
        } catch {
            print("try \(name): level not read: \(error)")
        }
        do {
            let music = try await readMusicFile(id: MediaID("try"), fileName: name, title: "try", in: folder)
            print("try \(name): readMusicFile gives \(music.duration.ticks) ticks")
        } catch {
            print("try \(name): readMusicFile throws \(error)")
        }
        let media = folder.appendingPathComponent("media")
        do {
            let music = try await importMusic(from: file, title: nil, to: media)
            print("try \(name): importMusic gives \(music.fileName), title \(music.title), \(music.duration.ticks) ticks")
        } catch {
            print("try \(name): importMusic throws \(error)")
        }
    }

    /// A sine at that pitch with a peak of 0.25 and 1800 ticks long, the same samples in every channel, given to the
    /// writer as 16 bit samples and written with the settings given.
    /// https://developer.apple.com/documentation/avfoundation/avassetwriter
    /// https://developer.apple.com/documentation/avfoundation/audio-settings
    /// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
    private func writeTone(
        to file: URL, fileType: AVFileType, settings: [String: Any], hertz: Int, rate: Int, channels: Int
    ) async throws {
        let count = 1800 * rate / 600
        var samples = [Int16](repeating: 0, count: count * channels)
        for index in 0..<count {
            let swing = sin(2 * Double.pi * Double(hertz) * Double(index) / Double(rate))
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
        var block: CMBlockBuffer?
        let allocated = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: bytes, blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil, offsetToData: 0, dataLength: bytes, flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block)
        guard described == noErr, allocated == kCMBlockBufferNoErr, let description, let filled = block else {
            throw EngineError.cannotWrite
        }
        let copied = CMBlockBufferReplaceDataBytes(
            with: samples, blockBuffer: filled, offsetIntoDestination: 0, dataLength: bytes)
        var made: CMSampleBuffer?
        let wrapped = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault, dataBuffer: filled, formatDescription: description,
            sampleCount: count, presentationTimeStamp: .zero, packetDescriptions: nil, sampleBufferOut: &made)
        guard copied == kCMBlockBufferNoErr, wrapped == noErr, let whole = made else { throw EngineError.cannotWrite }

        let writer = try AVAssetWriter(outputURL: file, fileType: fileType)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        guard writer.canAdd(input) else { throw EngineError.cannotWrite }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? EngineError.cannotWrite }
        writer.startSession(atSourceTime: .zero)
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? EngineError.cannotWrite }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        guard input.append(whole) else { throw writer.error ?? EngineError.cannotWrite }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 1800, timescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? EngineError.cannotWrite }
    }

    private func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-files-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
#endif
