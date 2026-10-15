#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ReelsmithCore

/// Reads the picture with its orientation applied, scales it so its long side is at most 3840 pixels and both sides
/// are even, and writes it as a still movie `<folder>/<id raw>.mov`: one picture track with the 709 colour
/// properties, of photoLongest. It is H.264 while the picture has at most 36864 blocks of 16 by 16, and HEVC above
/// or when the H.264 write fails. It holds the picture twice, at zero and one frame of 30 before the end. It gives
/// the MediaInfo of that movie: kind photo, the upright size, quarterTurns 0, hasSound false, duration photoLongest.
/// Throws cannotRead when it is no picture, cannotWrite when the movie cannot be written. Leaves nothing written
/// when it throws: the movie is written under a temporary name beside it, then renamed.
///
/// The metadata of the source is not carried, so no orientation is applied a second time.
///
/// https://developer.apple.com/documentation/coreimage/ciimage/init(contentsof:options:)
/// https://developer.apple.com/documentation/coreimage/ciimageoption/applyorientationproperty
/// https://developer.apple.com/documentation/coreimage/ciimage/transformed(by:highqualitydownsample:)
/// https://developer.apple.com/documentation/coreimage/ciimage/clampedtoextent()
/// https://developer.apple.com/documentation/coreimage/ciimage/cropped(to:)
/// https://developer.apple.com/documentation/coreimage/cicontext/render(_:to:bounds:colorspace:)
/// https://developer.apple.com/documentation/corevideo/cvpixelbuffercreate(_:_:_:_:_:_:)
/// https://developer.apple.com/documentation/avfoundation/avassetwriter
/// https://developer.apple.com/documentation/avfoundation/avassetwriterinputpixelbufferadaptor/append(_:withpresentationtime:)
/// https://developer.apple.com/documentation/avfoundation/avassetwriter/endsession(atsourcetime:)
public func importPhoto(from source: URL, id: MediaID, into folder: URL) async throws -> MediaInfo {
    guard let read = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]),
          !read.extent.isInfinite, !read.extent.isEmpty
    else { throw EngineError.cannotRead }
    let upright = read.transformed(by: CGAffineTransform(translationX: -read.extent.minX, y: -read.extent.minY))
    let scale = min(1, 3840 / max(upright.extent.width, upright.extent.height))
    let width = max(2, Int((upright.extent.width * scale).rounded()) / 2 * 2)
    let height = max(2, Int((upright.extent.height * scale).rounded()) / 2 * 2)
    // Clamped so the edges are not blended with the clear outside.
    let picture = upright.clampedToExtent()
        .transformed(
            by: CGAffineTransform(
                scaleX: CGFloat(width) / upright.extent.width, y: CGFloat(height) / upright.extent.height),
            highQualityDownsample: true)
        .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))

    let name = id.raw + ".mov"
    let file = folder.appendingPathComponent(name)
    let temporary = folder.appendingPathComponent(id.raw + "." + UUID().uuidString + ".tmp.mov")
    do {
        let frame = try pixelBuffer(of: picture, width: width, height: height)
        // H.264, as the test clips, while the picture fits the 36864 blocks of 16 by 16 of its level 5.2, HEVC above.
        // An encoder may still refuse a tall picture in H.264, so a failed H.264 write is made again in HEVC.
        let blocks = ((width + 15) / 16) * ((height + 15) / 16)
        let codec: AVVideoCodecType = blocks <= 36864 ? .h264 : .hevc
        do {
            try await writeStill(frame, codec: codec, width: width, height: height, to: temporary)
        } catch where codec == .h264 && !(error is CancellationError) {
            try? FileManager.default.removeItem(at: temporary)
            try await writeStill(frame, codec: .hevc, width: width, height: height, to: temporary)
        }
        try FileManager.default.moveItem(at: temporary, to: file)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw EngineError.cannotWrite
    }
    return MediaInfo(
        id: id, fileName: name, width: width, height: height, duration: MediaInfo.photoLongest, quarterTurns: 0,
        hasSound: false, kind: .photo)
}

/// `<folder>/<name>.png` in the photo's one colour, kept when it is there, the folder made when missing. Written
/// under a temporary name beside it, then renamed.
///
/// https://developer.apple.com/documentation/coreimage/cicolor/init(red:green:blue:alpha:colorspace:)
/// https://developer.apple.com/documentation/coreimage/ciimage/init(color:)
/// https://developer.apple.com/documentation/coreimage/cicontext/writepngrepresentation(of:to:format:colorspace:options:)
public func writeTestPhoto(_ photo: TestPhoto, to folder: URL) throws -> URL {
    let file = folder.appendingPathComponent(photo.name + ".png")
    if FileManager.default.fileExists(atPath: file.path) {
        return file
    }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let colour = CIColor(
            red: CGFloat(photo.colour.r) / 255, green: CGFloat(photo.colour.g) / 255,
            blue: CGFloat(photo.colour.b) / 255, alpha: 1, colorSpace: space)
    else { throw EngineError.cannotWrite }
    let picture = CIImage(color: colour).cropped(to: CGRect(x: 0, y: 0, width: photo.width, height: photo.height))
    let temporary = folder.appendingPathComponent(photo.name + "." + UUID().uuidString + ".tmp.png")
    do {
        try CIContext().writePNGRepresentation(of: picture, to: temporary, format: .RGBA8, colorSpace: space)
        try FileManager.default.moveItem(at: temporary, to: file)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw EngineError.cannotWrite
    }
    return file
}

/// The picture drawn in sRGB into a 32 bit BGRA buffer, the kind of frame the test clips are written from.
private func pixelBuffer(of picture: CIImage, width: Int, height: Int) throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes, &made)
    guard status == kCVReturnSuccess, let buffer = made, let space = CGColorSpace(name: CGColorSpace.sRGB)
    else { throw EngineError.cannotWrite }
    CIContext().render(picture, to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: space)
    return buffer
}

/// One picture track of photoLongest at a time scale of 600 that shows the frame from zero to its end. The frame is
/// appended at zero and once more one frame of 30 before the end, so the track holds two pictures and not one for
/// every frame, and the session ends at photoLongest. A writer that is still writing when a step fails is cancelled
/// before the throw.
///
/// https://developer.apple.com/documentation/avfoundation/avassetwriter/cancelwriting()
private func writeStill(
    _ frame: CVPixelBuffer, codec: AVVideoCodecType, width: Int, height: Int, to file: URL
) async throws {
    let writer = try AVAssetWriter(outputURL: file, fileType: .mov)
    writer.movieTimeScale = 600
    // https://developer.apple.com/documentation/avfoundation/video-settings
    let settings: [String: Any] = [
        AVVideoCodecKey: codec,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.mediaTimeScale = 600
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? EngineError.cannotWrite }
    do {
        writer.startSession(atSourceTime: .zero)
        let end = MediaInfo.photoLongest.ticks
        for ticks in [0, end - 20] {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? EngineError.cannotWrite }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            guard adaptor.append(frame, withPresentationTime: CMTime(value: ticks, timescale: 600))
            else { throw writer.error ?? EngineError.cannotWrite }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: end, timescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? EngineError.cannotWrite }
    } catch {
        // A writer that failed or finished is past cancelling.
        if writer.status == .writing {
            writer.cancelWriting()
        }
        throw error
    }
}
#endif
