#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import Foundation
import ReelsmithCore

/// Writes under a temporary name, then renames to `<folder>/<name>.mov` and returns it.
/// Keeps a file that is already there. Makes the folder when it is missing.
/// The file is a QuickTime file with one sound track and no picture: uncompressed 16 bit samples at the rate and
/// with the channels of the tone, a sine at `firstHertz` for the first half of its length and at `secondHertz`
/// for the second, with the peak of the tone, exactly as long as its ticks.
///
/// https://developer.apple.com/documentation/avfoundation/avassetwriter
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinput
/// https://developer.apple.com/documentation/avfoundation/audio-settings
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinput/isreadyformoremediadata
public func writeTestTone(_ tone: TestTone, to folder: URL) async throws -> URL {
    let file = folder.appendingPathComponent(tone.name + ".mov")
    if FileManager.default.fileExists(atPath: file.path) {
        return file
    }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let temporary = folder.appendingPathComponent(tone.name + "." + UUID().uuidString + ".tmp.mov")

    let writer = try AVAssetWriter(outputURL: temporary, fileType: .mov)
    writer.movieTimeScale = 600
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: tone.sampleRate,
        AVNumberOfChannelsKey: tone.channels,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]
    let sound = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
    writer.add(sound)

    guard writer.startWriting() else { throw writer.error ?? EngineError.cannotWrite }
    writer.startSession(atSourceTime: .zero)
    while !sound.isReadyForMoreMediaData {
        guard writer.status == .writing else { throw writer.error ?? EngineError.cannotWrite }
        try await Task.sleep(nanoseconds: 2_000_000)
    }
    let whole = try toneBuffer(of: tone)
    guard sound.append(whole) else { throw writer.error ?? EngineError.cannotWrite }
    sound.markAsFinished()

    writer.endSession(atSourceTime: CMTime(value: tone.duration.ticks, timescale: 600))
    await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error ?? EngineError.cannotWrite }

    try FileManager.default.moveItem(at: temporary, to: file)
    return file
}

/// The whole sound of the tone in one buffer, the same samples in every channel.
/// https://developer.apple.com/documentation/coremedia/cmaudioformatdescriptioncreate(allocator:asbd:layoutsize:layout:magiccookiesize:magiccookie:extensions:formatdescriptionout:)
/// https://developer.apple.com/documentation/coremedia/cmblockbuffercreatewithmemoryblock(allocator:memoryblock:blocklength:blockallocator:customblocksource:offsettodata:datalength:flags:blockbufferout:)
/// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
private func toneBuffer(of tone: TestTone) throws -> CMSampleBuffer {
    let rate = tone.sampleRate
    let channels = tone.channels
    let count = Int(tone.duration.ticks) * rate / 600
    let half = count / 2
    var samples = [Int16](repeating: 0, count: count * channels)
    for index in 0..<count {
        let hertz = index < half ? tone.firstHertz : tone.secondHertz
        let value = Int16((tone.peak * 32767 * sin(2 * Double.pi * Double(hertz) * Double(index) / Double(rate))).rounded())
        for channel in 0..<channels {
            samples[index * channels + channel] = value
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
    guard described == noErr, allocated == kCMBlockBufferNoErr, let description, let block else {
        throw EngineError.cannotWrite
    }
    let copied = CMBlockBufferReplaceDataBytes(
        with: samples, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)

    var made: CMSampleBuffer?
    let wrapped = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
        allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: description, sampleCount: count,
        presentationTimeStamp: .zero, packetDescriptions: nil, sampleBufferOut: &made)
    guard copied == kCMBlockBufferNoErr, wrapped == noErr, let buffer = made else { throw EngineError.cannotWrite }
    return buffer
}
#endif
