#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ReelsmithCore

/// Writes under a temporary name, then renames to `<folder>/<name>.mov` and returns it.
/// Keeps a file that is already there. Makes the folder when it is missing.
///
/// https://developer.apple.com/documentation/avfoundation/avassetwriter
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinput
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinputpixelbufferadaptor
public func writeTestClip(_ clip: TestClip, to folder: URL) async throws -> URL {
    let file = folder.appendingPathComponent(clip.name + ".mov")
    if FileManager.default.fileExists(atPath: file.path) {
        return file
    }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let temporary = folder.appendingPathComponent(clip.name + "." + UUID().uuidString + ".tmp.mov")

    let writer = try AVAssetWriter(outputURL: temporary, fileType: .mov)
    writer.movieTimeScale = 600

    // https://developer.apple.com/documentation/avfoundation/video-settings
    let pictureSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: clip.storedWidth,
        AVVideoHeightKey: clip.storedHeight,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false],
    ]
    let picture = AVAssetWriterInput(mediaType: .video, outputSettings: pictureSettings)
    picture.mediaTimeScale = 600
    if clip.quarterTurns == 1 {
        // One clockwise quarter turn shows the stored picture upright.
        picture.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(clip.storedHeight), ty: 0)
    }
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: picture, sourcePixelBufferAttributes: nil)
    writer.add(picture)

    var sound: AVAssetWriterInput?
    if clip.hasSound {
        // https://developer.apple.com/documentation/avfoundation/audio-settings
        let soundSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: soundSettings)
        writer.add(input)
        sound = input
    }

    guard writer.startWriting() else { throw writer.error ?? EngineError.cannotWrite }
    writer.startSession(atSourceTime: .zero)

    // The sound goes in first and whole, so the writer never holds the picture back to wait for it.
    if let sound {
        try await waitUntilReady(sound, writer)
        let whole = try tone(for: clip)
        guard sound.append(whole) else { throw writer.error ?? EngineError.cannotWrite }
        sound.markAsFinished()
    }

    let frame = try pictureBuffer(for: clip)
    let frames = clip.duration.ticks * Int64(clip.framesPerSecond) / 600
    for index in 0..<frames {
        try await waitUntilReady(picture, writer)
        let time = CMTime(value: index * 600 / Int64(clip.framesPerSecond), timescale: 600)
        guard adaptor.append(frame, withPresentationTime: time) else { throw writer.error ?? EngineError.cannotWrite }
    }
    picture.markAsFinished()

    writer.endSession(atSourceTime: CMTime(value: clip.duration.ticks, timescale: 600))
    await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error ?? EngineError.cannotWrite }

    try FileManager.default.moveItem(at: temporary, to: file)
    return file
}

/// https://developer.apple.com/documentation/avfoundation/avassetwriterinput/isreadyformoremediadata
private func waitUntilReady(_ input: AVAssetWriterInput, _ writer: AVAssetWriter) async throws {
    while !input.isReadyForMoreMediaData {
        guard writer.status == .writing else { throw writer.error ?? EngineError.cannotWrite }
        try await Task.sleep(nanoseconds: 2_000_000)
    }
}

/// One frame of the clip: the left half in one colour, the right half in the other.
/// https://developer.apple.com/documentation/corevideo/cvpixelbuffercreate(_:_:_:_:_:_:)
private func pictureBuffer(for clip: TestClip) throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault, clip.storedWidth, clip.storedHeight, kCVPixelFormatType_32BGRA, attributes, &made)
    guard status == kCVReturnSuccess, let buffer = made else { throw EngineError.cannotWrite }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw EngineError.cannotWrite }
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    let firstRow = base.assumingMemoryBound(to: UInt8.self)
    for x in 0..<clip.storedWidth {
        let colour = x < clip.storedWidth / 2 ? clip.left : clip.right
        firstRow[x * 4] = colour.b
        firstRow[x * 4 + 1] = colour.g
        firstRow[x * 4 + 2] = colour.r
        firstRow[x * 4 + 3] = 255
    }
    for y in 1..<clip.storedHeight {
        memcpy(base + y * rowBytes, base, clip.storedWidth * 4)
    }
    return buffer
}

/// The whole sound of the clip in one buffer: mono, 16 bit, 44100 a second, a 440 Hz sine at half of full scale.
/// https://developer.apple.com/documentation/coremedia/cmaudioformatdescriptioncreate(allocator:asbd:layoutsize:layout:magiccookiesize:magiccookie:extensions:formatdescriptionout:)
/// https://developer.apple.com/documentation/coremedia/cmblockbuffercreatewithmemoryblock(allocator:memoryblock:blocklength:blockallocator:customblocksource:offsettodata:datalength:flags:blockbufferout:)
/// https://developer.apple.com/documentation/coremedia/cmaudiosamplebuffercreatereadywithpacketdescriptions(allocator:databuffer:formatdescription:samplecount:presentationtimestamp:packetdescriptions:samplebufferout:)
private func tone(for clip: TestClip) throws -> CMSampleBuffer {
    let count = Int(clip.duration.ticks) * 44100 / 600
    var samples = [Int16](repeating: 0, count: count)
    for index in 0..<count {
        samples[index] = Int16((0.5 * 32767 * sin(2 * Double.pi * 440 * Double(index) / 44100)).rounded())
    }

    var format = AudioStreamBasicDescription(
        mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2,
        mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
    var description: CMAudioFormatDescription?
    let described = CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault, asbd: &format, layoutSize: 0, layout: nil, magicCookieSize: 0,
        magicCookie: nil, extensions: nil, formatDescriptionOut: &description)

    var block: CMBlockBuffer?
    let allocated = CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: count * 2, blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil, offsetToData: 0, dataLength: count * 2, flags: kCMBlockBufferAssureMemoryNowFlag,
        blockBufferOut: &block)
    guard described == noErr, allocated == kCMBlockBufferNoErr, let description, let block else {
        throw EngineError.cannotWrite
    }
    let copied = CMBlockBufferReplaceDataBytes(
        with: samples, blockBuffer: block, offsetIntoDestination: 0, dataLength: count * 2)

    var made: CMSampleBuffer?
    let wrapped = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
        allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: description, sampleCount: count,
        presentationTimeStamp: .zero, packetDescriptions: nil, sampleBufferOut: &made)
    guard copied == kCMBlockBufferNoErr, wrapped == noErr, let buffer = made else { throw EngineError.cannotWrite }
    return buffer
}
#endif
