#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore

/// https://developer.apple.com/documentation/avfoundation/avplayeritem/init(asset:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/videocomposition
@MainActor
public func makePlayerItem(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL) async throws -> AVPlayerItem {
    let built = try await buildComposition(plan: plan, media: media, mediaFolder: mediaFolder)
    let item = AVPlayerItem(asset: built.composition)
    item.videoComposition = built.videoComposition
    return item
}

/// The one builder for the player item and for the export. One picture track, one sound track when a segment
/// has sound, and one instruction per segment that puts its upright picture at its place on the canvas.
/// Throws `sourceMissing` when a file is not in the media folder and `cannotRead` when a file cannot be used.
///
/// https://developer.apple.com/documentation/avfoundation/avmutablecomposition
/// https://developer.apple.com/documentation/avfoundation/avmutablecompositiontrack/inserttimerange(_:of:at:)
/// https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:)
/// https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition
/// https://developer.apple.com/documentation/avfoundation/avmutablevideocompositioninstruction
/// https://developer.apple.com/documentation/avfoundation/avmutablevideocompositionlayerinstruction
func buildComposition(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL) async throws
    -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition) {
    let composition = AVMutableComposition()
    guard let picture = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw EngineError.cannotRead }
    var sound: AVMutableCompositionTrack?
    var instructions: [AVMutableVideoCompositionInstruction] = []

    for segment in plan.segments {
        guard let info = media[segment.media] else { throw EngineError.sourceMissing(segment.media) }
        let file = mediaFolder.appendingPathComponent(info.fileName)
        guard FileManager.default.fileExists(atPath: file.path) else { throw EngineError.sourceMissing(segment.media) }

        let asset = AVURLAsset(url: file)
        let range = CMTimeRange(
            start: CMTime(value: segment.sourceStart.ticks, timescale: 600),
            duration: CMTime(value: segment.duration.ticks, timescale: 600))
        let start = CMTime(value: segment.timelineStart.ticks, timescale: 600)

        do {
            let pictureTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourcePicture = pictureTracks.first else { throw EngineError.cannotRead }
            try picture.insertTimeRange(range, of: sourcePicture, at: start)

            if segment.hasSound {
                let soundTracks = try await asset.loadTracks(withMediaType: .audio)
                if let sourceSound = soundTracks.first {
                    if sound == nil {
                        sound = composition.addMutableTrack(
                            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    }
                    guard let track = sound else { throw EngineError.cannotRead }
                    try track.insertTimeRange(range, of: sourceSound, at: start)
                }
            }
        } catch {
            throw EngineError.cannotRead
        }

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: picture)
        layer.setTransform(transform(for: segment.placement, width: info.width, height: info.height), at: start)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: start, duration: range.duration)
        instruction.layerInstructions = [layer]
        instructions.append(instruction)
    }

    // Standard range colour properties, so a high dynamic range source is converted for preview and export alike.
    // https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition/colorprimaries
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = CGSize(width: Project.canvasWidth, height: Project.canvasHeight)
    videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(Project.framesPerSecond))
    videoComposition.instructions = instructions
    videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
    videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
    videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
    return (composition, videoComposition)
}

/// From the stored picture, with its origin at the top left, to its place on the canvas: the quarter turns of
/// the placement first, then the scale to the size of the place, then the move to it.
private func transform(for placement: Placement, width: Int, height: Int) -> CGAffineTransform {
    let stored = CGSize(width: width, height: height)
    var upright = stored
    var turn = CGAffineTransform.identity
    switch placement.quarterTurns {
    case 1:
        turn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: stored.height, ty: 0)
        upright = CGSize(width: stored.height, height: stored.width)
    case 2:
        turn = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: stored.width, ty: stored.height)
    case 3:
        turn = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: stored.width)
        upright = CGSize(width: stored.height, height: stored.width)
    default:
        break
    }
    let scale = CGAffineTransform(
        scaleX: CGFloat(placement.width) / upright.width, y: CGFloat(placement.height) / upright.height)
    let move = CGAffineTransform(translationX: CGFloat(placement.x), y: CGFloat(placement.y))
    return turn.concatenating(scale).concatenating(move)
}
#endif
