#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore

/// https://developer.apple.com/documentation/avfoundation/avplayeritem/init(asset:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/videocomposition
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/audiomix
@MainActor
public func makePlayerItem(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL) async throws -> AVPlayerItem {
    let built = try await buildComposition(plan: plan, media: media, mediaFolder: mediaFolder)
    let item = AVPlayerItem(asset: built.composition)
    item.videoComposition = built.videoComposition
    item.audioMix = built.audioMix
    return item
}

/// For an item that `makePlayerItem` made and a plan with the same segments: gives the item a new video
/// composition built from the plan, so the texts of the plan are drawn from the next frame on. Loads no file
/// and reads no asset: the picture track of each segment and the text pictures the plan uses again are taken
/// from the instructions the item has. Throws `cannotRead` for an item it did not make, a plan with another
/// number of segments or a segment whose time range is not that of its instruction, and `sourceMissing` as
/// `makePlayerItem` does when the plan names media with no facts. After a throw the item has the video composition it had.
///
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/videocomposition
/// https://developer.apple.com/documentation/avfoundation/avvideocomposition/instructions
@MainActor
public func refreshPicture(of item: AVPlayerItem, plan: RenderPlan, media: [MediaID: MediaInfo]) throws {
    guard let pieces = item.videoComposition?.instructions as? [PieceInstruction],
          pieces.count == plan.segments.count
    else { throw EngineError.cannotRead }
    for (segment, piece) in zip(plan.segments, pieces) {
        let range = CMTimeRange(
            start: CMTime(value: segment.timelineStart.ticks, timescale: 600),
            duration: CMTime(value: segment.duration.ticks, timescale: 600))
        guard range == piece.timeRange else { throw EngineError.cannotRead }
    }
    item.videoComposition = try videoComposition(
        plan: plan, media: media, tracks: pieces.map { $0.track }, kept: pieces.flatMap { $0.texts })
}

/// The one builder for the player item and for the export. One picture track, one sound track when a segment
/// has sound, one more sound track when the plan has music, the video composition of the plan, and the audio mix
/// with one set of parameters for each sound track.
/// Throws `sourceMissing` when a file is not in the media folder and `cannotRead` when a file cannot be used.
///
/// https://developer.apple.com/documentation/avfoundation/avmutablecomposition
/// https://developer.apple.com/documentation/avfoundation/avmutablecompositiontrack/inserttimerange(_:of:at:)
/// https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:)
func buildComposition(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL) async throws
    -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition, audioMix: AVAudioMix) {
    let composition = AVMutableComposition()
    guard let picture = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw EngineError.cannotRead }
    var sound: AVMutableCompositionTrack?

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
    }

    var music: CMPersistentTrackID?
    if let layer = plan.sound.music {
        music = try await addMusic(layer, to: composition, mediaFolder: mediaFolder)
    }
    let mix = audioMix(for: plan, clipTrack: sound?.trackID, musicTrack: music)

    let tracks = [CMPersistentTrackID](repeating: picture.trackID, count: plan.segments.count)
    return (composition, try videoComposition(plan: plan, media: media, tracks: tracks, kept: []), mix)
}

/// Lays `duration` of the music file from `sourceStart` at zero on a sound track of its own, and gives the id of
/// that track.
/// Throws `sourceMissing` with the id of the layer when the file is not in the media folder, and `cannotRead`
/// when it has no sound track or cannot be put into the composition.
private func addMusic(_ layer: MusicLayer, to composition: AVMutableComposition, mediaFolder: URL) async throws
    -> CMPersistentTrackID {
    let file = mediaFolder.appendingPathComponent(layer.fileName)
    guard FileManager.default.fileExists(atPath: file.path) else { throw EngineError.sourceMissing(layer.media) }
    let asset = AVURLAsset(url: file)
    guard let track = composition.addMutableTrack(
        withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw EngineError.cannotRead }
    do {
        let soundTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let source = soundTracks.first else { throw EngineError.cannotRead }
        let range = CMTimeRange(
            start: CMTime(value: layer.sourceStart.ticks, timescale: 600),
            duration: CMTime(value: layer.duration.ticks, timescale: 600))
        try track.insertTimeRange(range, of: source, at: .zero)
    } catch {
        throw EngineError.cannotRead
    }
    return track.trackID
}

/// The whole mix of a plan, for a new item and an export alike, made from the plan and the ids of its sound
/// tracks and reading no file. The clip track holds `clipVolume` times the volume of each segment that has sound,
/// set at its start in the order of the plan, so 0 while the clips are muted. The music track rises from 0 to the
/// music's `volume` over the first `fadeIn`, stands at it up to the last `fadeOut` and falls to 0 over it. A fade
/// of zero sets no ramp. A track id that is nil gets no parameters.
///
/// https://developer.apple.com/documentation/avfoundation/avmutableaudiomix
/// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters
/// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/setvolume(_:at:)
/// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/setvolumeramp(fromstartvolume:toendvolume:timerange:)
private func audioMix(for plan: RenderPlan, clipTrack: CMPersistentTrackID?, musicTrack: CMPersistentTrackID?)
    -> AVAudioMix {
    var parameters: [AVMutableAudioMixInputParameters] = []
    if let track = clipTrack {
        let clips = AVMutableAudioMixInputParameters()
        clips.trackID = track
        for segment in plan.segments where segment.hasSound {
            clips.setVolume(
                Float(plan.sound.clipVolume * segment.volume),
                at: CMTime(value: segment.timelineStart.ticks, timescale: 600))
        }
        parameters.append(clips)
    }
    if let track = musicTrack, let layer = plan.sound.music {
        let volume = Float(layer.volume)
        let music = AVMutableAudioMixInputParameters()
        music.trackID = track
        if layer.fadeIn.ticks > 0 {
            music.setVolumeRamp(
                fromStartVolume: 0, toEndVolume: volume,
                timeRange: CMTimeRange(start: .zero, duration: CMTime(value: layer.fadeIn.ticks, timescale: 600)))
        } else {
            music.setVolume(volume, at: .zero)
        }
        if layer.fadeOut.ticks > 0 {
            music.setVolumeRamp(
                fromStartVolume: volume, toEndVolume: 0,
                timeRange: CMTimeRange(
                    start: CMTime(value: layer.duration.ticks - layer.fadeOut.ticks, timescale: 600),
                    duration: CMTime(value: layer.fadeOut.ticks, timescale: 600)))
        }
        parameters.append(music)
    }
    let mix = AVMutableAudioMix()
    mix.inputParameters = parameters
    return mix
}

/// The video composition of a plan, for a new item, an export and a refresh alike: one instruction per segment
/// that puts its upright picture at its place on the canvas and holds the texts whose time overlaps it. It names
/// `Compositor`, which draws every frame from those instructions. `tracks` names the picture track of each
/// segment. `kept` holds the texts of the video composition before it, whose pictures are used again.
///
/// https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition
/// https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition/customvideocompositorclass
private func videoComposition(
    plan: RenderPlan, media: [MediaID: MediaInfo], tracks: [CMPersistentTrackID], kept: [PieceText]
) throws -> AVMutableVideoComposition {
    var kept = kept
    var instructions: [PieceInstruction] = []
    for (segment, track) in zip(plan.segments, tracks) {
        guard let info = media[segment.media] else { throw EngineError.sourceMissing(segment.media) }
        let range = CMTimeRange(
            start: CMTime(value: segment.timelineStart.ticks, timescale: 600),
            duration: CMTime(value: segment.duration.ticks, timescale: 600))
        // The transform counts both pictures from the top left, the compositor from the bottom left.
        let placing = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(info.height))
            .concatenating(transform(for: segment.placement, width: info.width, height: info.height))
            .concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(plan.height)))
        let made = pieceTexts(of: plan, in: range, kept: kept)
        kept += made.texts
        instructions.append(PieceInstruction(
            timeRange: range, track: track, placing: placing, texts: made.texts, drawn: made.drawn))
    }

    // Standard range colour properties, so a high dynamic range source is converted for preview and export alike.
    // https://developer.apple.com/documentation/avfoundation/avmutablevideocomposition/colorprimaries
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = CGSize(width: plan.width, height: plan.height)
    videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(plan.framesPerSecond))
    videoComposition.instructions = instructions
    videoComposition.customVideoCompositorClass = Compositor.self
    videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
    videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
    videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
    return videoComposition
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
