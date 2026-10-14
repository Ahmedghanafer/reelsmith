#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The colours of the frames of the blink clip, so a file of 60 frames a second whose frames are 30 shown twice
/// reads wrong.
enum BlinkClip {
    /// The frames 0, 2, 4 and so on.
    static let even = RGB(r: 255, g: 0, b: 0)
    /// The frames 1, 3, 5 and so on.
    static let odd = RGB(r: 0, g: 0, b: 255)
}

/// Writes `<folder>/blink.mov` and returns its facts: H.264 with the 709 colour properties, 1920 by 1080, no turn,
/// no sound, one second (600 ticks) at 60 frames a second, frame n at n times 10 ticks, every pixel of an even
/// frame red and of an odd frame blue. Keeps a file that is already there. Makes the folder when it is missing.
///
/// https://developer.apple.com/documentation/avfoundation/avassetwriter
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinput
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinputpixelbufferadaptor
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinput/isreadyformoremediadata
func writeBlinkClip(to folder: URL) async throws -> MediaInfo {
    let info = MediaInfo(
        id: MediaID("blink"), fileName: "blink.mov", width: 1920, height: 1080, duration: Time(ticks: 600),
        quarterTurns: 0, hasSound: false)
    let file = folder.appendingPathComponent(info.fileName)
    if FileManager.default.fileExists(atPath: file.path) {
        return info
    }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let temporary = folder.appendingPathComponent("blink." + UUID().uuidString + ".tmp.mov")

    let writer = try AVAssetWriter(outputURL: temporary, fileType: .mov)
    writer.movieTimeScale = 600
    // https://developer.apple.com/documentation/avfoundation/video-settings
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1920,
        AVVideoHeightKey: 1080,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false],
    ]
    let picture = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    picture.mediaTimeScale = 600
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: picture, sourcePixelBufferAttributes: nil)
    writer.add(picture)
    guard writer.startWriting() else { throw writer.error ?? EngineError.cannotWrite }
    writer.startSession(atSourceTime: .zero)

    let even = try blinkBuffer(BlinkClip.even)
    let odd = try blinkBuffer(BlinkClip.odd)
    for index in 0..<60 {
        while !picture.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? EngineError.cannotWrite }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        let time = CMTime(value: Int64(index) * 10, timescale: 600)
        let frame = index % 2 == 0 ? even : odd
        guard adaptor.append(frame, withPresentationTime: time) else { throw writer.error ?? EngineError.cannotWrite }
    }
    picture.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: info.duration.ticks, timescale: 600))
    await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error ?? EngineError.cannotWrite }

    try FileManager.default.moveItem(at: temporary, to: file)
    return info
}

/// One frame of 1920 by 1080 in one colour.
/// https://developer.apple.com/documentation/corevideo/cvpixelbuffercreate(_:_:_:_:_:_:)
private func blinkBuffer(_ colour: RGB) throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
    let status = CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32BGRA, attributes, &made)
    guard status == kCVReturnSuccess, let buffer = made else { throw EngineError.cannotWrite }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw EngineError.cannotWrite }
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    let firstRow = base.assumingMemoryBound(to: UInt8.self)
    for x in 0..<1920 {
        firstRow[x * 4] = colour.b
        firstRow[x * 4 + 1] = colour.g
        firstRow[x * 4 + 2] = colour.r
        firstRow[x * 4 + 3] = 255
    }
    for y in 1..<1080 {
        memcpy(base + y * rowBytes, base, 1920 * 4)
    }
    return buffer
}
#endif
