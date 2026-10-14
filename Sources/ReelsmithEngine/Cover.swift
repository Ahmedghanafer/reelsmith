#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ReelsmithCore

/// The frame at zero of the plan, made by buildComposition and its video composition through AVAssetImageGenerator
/// with both tolerances zero, scaled by Core Image so that its long side is at most 360 pixels, written as a JPEG
/// by Core Image to file, replacing a file that is there. Throws nothingToExport for a plan with no segment,
/// sourceMissing and cannotRead as buildComposition does, cannotWrite when the file cannot be written.
/// Writes nothing when it throws.
///
/// A frame the generator cannot give throws `cannotRead`. The JPEG is written under a temporary name beside the
/// file and renamed when it is whole.
///
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/requestedtimetolerancebefore
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/requestedtimetoleranceafter
/// https://developer.apple.com/documentation/coreimage/ciimage/init(cgimage:)
/// https://developer.apple.com/documentation/coreimage/ciimage/transformed(by:)
/// https://developer.apple.com/documentation/coreimage/cicontext/writejpegrepresentation(of:to:colorspace:options:)
public func writeCover(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL, to file: URL) async throws {
    guard !plan.segments.isEmpty else { throw EngineError.nothingToExport }
    let folder = file.deletingLastPathComponent()
    guard FileManager.default.isWritableFile(atPath: folder.path) else { throw EngineError.cannotWrite }

    let built = try await buildComposition(plan: plan, media: media, mediaFolder: mediaFolder)
    let generator = AVAssetImageGenerator(asset: built.composition)
    generator.videoComposition = built.videoComposition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let frame: CGImage
    do {
        frame = try await generator.image(at: .zero).image
    } catch {
        throw EngineError.cannotRead
    }

    let scale = min(1, 360 / CGFloat(max(frame.width, frame.height)))
    let small = CIImage(cgImage: frame).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let temporary = folder.appendingPathComponent(UUID().uuidString + ".tmp.jpg")
    do {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw EngineError.cannotWrite }
        try CIContext().writeJPEGRepresentation(of: small, to: temporary, colorSpace: space)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        try FileManager.default.moveItem(at: temporary, to: file)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw EngineError.cannotWrite
    }
}
#endif
