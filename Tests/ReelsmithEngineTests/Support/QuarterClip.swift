#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The colours of the four quarters of the stored picture of a quarter clip.
enum QuarterClip {
    static let topLeft = RGB(r: 255, g: 0, b: 0)
    static let topRight = RGB(r: 0, g: 255, b: 0)
    static let bottomLeft = RGB(r: 0, g: 0, b: 255)
    static let bottomRight = RGB(r: 255, g: 255, b: 255)
}

/// Writes `<folder>/<name>.mov` and returns its facts: 1920 by 1080, no turn, no sound, four quarters of four
/// colours, so a picture drawn upside down or mirrored reads wrong. One second of frames, the first of them at
/// `firstFrame`. The file starts at zero, so a first frame later than zero leaves a stretch with no picture at
/// its start, and the length in the facts counts that stretch. Keeps a file that is already there.
///
/// https://developer.apple.com/documentation/avfoundation/avassetwriter/startsession(atsourcetime:)
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinputpixelbufferadaptor
func writeQuarterClip(named name: String, firstFrame: Time, to folder: URL) async throws -> MediaInfo {
    let info = MediaInfo(
        id: MediaID(name), fileName: name + ".mov", width: 1920, height: 1080,
        duration: firstFrame + Time(ticks: 600), quarterTurns: 0, hasSound: false)
    let file = folder.appendingPathComponent(info.fileName)
    if FileManager.default.fileExists(atPath: file.path) {
        return info
    }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    let writer = try AVAssetWriter(outputURL: file, fileType: .mov)
    writer.movieTimeScale = 600
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

    let frame = try quarterBuffer()
    for index in 0..<30 {
        while !picture.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? EngineError.cannotWrite }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        let time = CMTime(value: firstFrame.ticks + Int64(index) * 20, timescale: 600)
        guard adaptor.append(frame, withPresentationTime: time) else { throw writer.error ?? EngineError.cannotWrite }
    }
    picture.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: info.duration.ticks, timescale: 600))
    await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error ?? EngineError.cannotWrite }
    return info
}

/// https://developer.apple.com/documentation/corevideo/cvpixelbuffercreate(_:_:_:_:_:_:)
private func quarterBuffer() throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
    let status = CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32BGRA, attributes, &made)
    guard status == kCVReturnSuccess, let buffer = made else { throw EngineError.cannotWrite }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw EngineError.cannotWrite }
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<1080 {
        let row = (base + y * rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<1920 {
            let colour: RGB
            if y < 540 {
                colour = x < 960 ? QuarterClip.topLeft : QuarterClip.topRight
            } else {
                colour = x < 960 ? QuarterClip.bottomLeft : QuarterClip.bottomRight
            }
            row[x * 4] = colour.b
            row[x * 4 + 1] = colour.g
            row[x * 4 + 2] = colour.r
            row[x * 4 + 3] = 255
        }
    }
    return buffer
}
#endif
