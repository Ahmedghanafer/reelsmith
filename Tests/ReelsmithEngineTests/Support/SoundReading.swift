#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore

/// What a read of a level could not do, in words that name the file or the window.
struct SoundReadingError: Error, CustomStringConvertible {
    var description: String
}

/// The size of the part of the first sound track that swings at that pitch, from 0 to 1 of full scale, over the window.
/// Reads the first channel as 16 bit samples at the rate of the track. A sine with a peak of 0.5 reads 0.5.
/// Fails the test when the window is not a whole number of tenths of a second. Prints the level.
///
/// https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput
/// https://developer.apple.com/documentation/avfoundation/avassetreader/timerange
func toneLevel(of file: URL, hertz: Int, from start: Time, to end: Time) async throws -> Double {
    let window = try wholeTenths(from: start, to: end)
    let asset = AVURLAsset(url: file)
    let soundTracks = try await asset.loadTracks(withMediaType: .audio)
    guard let track = soundTracks.first else {
        throw SoundReadingError(description: "no sound track in " + file.lastPathComponent)
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: sixteenBitSamples)
    let level = try pitchLevel(reader: reader, output: output, hertz: hertz, window: window)
    print("level of \(hertz) Hz from \(start.ticks) to \(end.ticks) ticks in \(file.lastPathComponent): \(level)")
    return level
}

/// The same number for all sound tracks of the asset mixed with the mix, read with no export. Prints the level.
/// A volume that is held reads as in the exported file. Inside a ramp of the mix this read comes out lower than
/// the exported file does, so the size of a ramp is asserted on an exported file and never here.
///
/// https://developer.apple.com/documentation/avfoundation/avassetreaderaudiomixoutput
/// https://developer.apple.com/documentation/avfoundation/avassetreaderaudiomixoutput/audiomix
func mixedToneLevel(of asset: AVAsset, mix: AVAudioMix?, hertz: Int, from start: Time, to end: Time) async throws -> Double {
    let window = try wholeTenths(from: start, to: end)
    let soundTracks = try await asset.loadTracks(withMediaType: .audio)
    guard !soundTracks.isEmpty else {
        throw SoundReadingError(description: "no sound track in the asset")
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderAudioMixOutput(audioTracks: soundTracks, audioSettings: sixteenBitSamples)
    output.audioMix = mix
    let level = try pitchLevel(reader: reader, output: output, hertz: hertz, window: window)
    print("level of \(hertz) Hz from \(start.ticks) to \(end.ticks) ticks through the mix: \(level)")
    return level
}

/// Uncompressed 16 bit samples, the channels side by side, at the rate of what is read.
/// https://developer.apple.com/documentation/avfoundation/audio-settings
private let sixteenBitSamples: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
    AVLinearPCMIsNonInterleaved: false,
]

/// The window as a time range. Throws, which fails the test, unless its length is a whole number of tenths of a
/// second: only then does it hold whole periods of a pitch that is a multiple of 10 Hz.
private func wholeTenths(from start: Time, to end: Time) throws -> CMTimeRange {
    let length = end.ticks - start.ticks
    guard start.ticks >= 0, length > 0, length % 60 == 0 else {
        throw SoundReadingError(
            description: "the window from \(start.ticks) to \(end.ticks) ticks is not a whole number of tenths of a second")
    }
    return CMTimeRange(
        start: CMTime(value: start.ticks, timescale: 600), duration: CMTime(value: length, timescale: 600))
}

/// Reads the window and weighs the first channel against a sine and a cosine of the pitch. Each sample takes its
/// place in the window from the time of its buffer, so a buffer that begins before the window adds nothing wrong.
/// Throws unless the window is filled with samples from its first to its last.
///
/// https://developer.apple.com/documentation/coremedia/cmsamplebuffergetpresentationtimestamp(_:)
/// https://developer.apple.com/documentation/coremedia/cmaudioformatdescriptiongetstreambasicdescription(_:)
/// https://developer.apple.com/documentation/coremedia/cmblockbuffercopydatabytes(_:atoffset:datalength:destination:)
private func pitchLevel(reader: AVAssetReader, output: AVAssetReaderOutput, hertz: Int, window: CMTimeRange) throws -> Double {
    reader.timeRange = window
    reader.add(output)
    guard reader.startReading() else {
        throw reader.error ?? SoundReadingError(description: "the reader did not start")
    }
    var sine = 0.0
    var cosine = 0.0
    var rate = 0.0
    var placed = 0
    while let buffer = output.copyNextSampleBuffer() {
        guard let block = CMSampleBufferGetDataBuffer(buffer),
              let format = CMSampleBufferGetFormatDescription(buffer),
              let basic = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else { continue }
        let channels = Int(basic.pointee.mChannelsPerFrame)
        let length = CMBlockBufferGetDataLength(block)
        guard channels > 0, basic.pointee.mSampleRate > 0, length >= 2 else { continue }
        rate = basic.pointee.mSampleRate

        var samples = [Int16](repeating: 0, count: length / 2)
        let status = samples.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
        }
        guard status == kCMBlockBufferNoErr else {
            throw SoundReadingError(description: "the samples could not be copied")
        }

        let began = CMSampleBufferGetPresentationTimeStamp(buffer) - window.start
        let first = Int((began.seconds * rate).rounded())
        let wanted = Int((window.duration.seconds * rate).rounded())
        for frame in 0..<(samples.count / channels) {
            let place = first + frame
            guard place >= 0, place < wanted else { continue }
            placed += 1
            let angle = 2 * Double.pi * Double(hertz) * Double(place) / rate
            let value = Double(samples[frame * channels]) / 32768
            sine += value * sin(angle)
            cosine += value * cos(angle)
        }
    }
    guard reader.status == .completed else {
        throw reader.error ?? SoundReadingError(description: "the reader did not finish")
    }
    // A window the sound does not fill would read low, and a silent read would then prove nothing.
    let wanted = Int((window.duration.seconds * rate).rounded())
    guard rate > 0, placed == wanted else {
        throw SoundReadingError(description: "the window holds \(placed) samples of the \(wanted) it is long")
    }
    return 2 * (sine * sine + cosine * cosine).squareRoot() / (window.duration.seconds * rate)
}
#endif
