#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore

/// The frames of a media for the blocks of the strip, one at each of `BlockFrames.times(of:)`, made from its file
/// in the media folder by AVAssetImageGenerator with a tolerance of half a step on both sides, upright, at most 168
/// pixels on the long side. A photo's still movie gives its one frame at zero. Throws sourceMissing when the file
/// is not in the folder and cannotRead when a frame cannot be made, as writeCover does.
///
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/init(asset:)
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/appliespreferredtracktransform
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/maximumsize
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/requestedtimetolerancebefore
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/requestedtimetoleranceafter
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
public func makeBlockFrames(of media: MediaInfo, mediaFolder: URL) async throws -> [Time: CGImage] {
    let file = mediaFolder.appendingPathComponent(media.fileName)
    guard FileManager.default.fileExists(atPath: file.path) else { throw EngineError.sourceMissing(media.id) }
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 168, height: 168)
    let half = CMTime(value: BlockFrames.step.ticks / 2, timescale: 600)
    generator.requestedTimeToleranceBefore = half
    generator.requestedTimeToleranceAfter = half
    var frames: [Time: CGImage] = [:]
    for time in BlockFrames.times(of: media) {
        do {
            frames[time] = try await generator.image(at: CMTime(value: time.ticks, timescale: 600)).image
        } catch {
            throw EngineError.cannotRead
        }
    }
    return frames
}
#endif
