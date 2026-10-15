#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import MediaToolbox
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

/// Gives an item `makePlayerItem` made the audio mix of the plan, made by the same function as at a build. The
/// sound tracks of the item's composition, in the order of their ids, are the clip track when a segment has sound,
/// then the music track when the plan has music, the same in number whatever the volumes. The new mix carries a new
/// tap of the clip track. Throws `cannotRead` when the item is not a composition of ours or its tracks do not match
/// the plan. After a throw the item has the mix it had. Reads no file.
///
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/audiomix
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/asset
/// https://developer.apple.com/documentation/avfoundation/avcomposition/tracks
@MainActor
public func refreshSound(of item: AVPlayerItem, plan: RenderPlan) throws {
    guard let composition = item.asset as? AVComposition else { throw EngineError.cannotRead }
    let ids = composition.tracks.filter { $0.mediaType == .audio }.map { $0.trackID }.sorted()
    let clipSound = plan.segments.contains { $0.hasSound }
    let music = plan.sound.music != nil
    guard ids.count == (clipSound ? 1 : 0) + (music ? 1 : 0) else { throw EngineError.cannotRead }
    item.audioMix = audioMix(
        for: plan, clipTrack: clipSound ? ids.first : nil, musicTrack: music ? ids.last : nil)
}

/// The one builder for the player item and for the export. One picture track, one sound track when a segment
/// has sound, one more sound track when the plan has music, whatever the volumes, the video composition of the
/// plan, and the audio mix with one set of parameters for each sound track and a tap on the clip track.
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
/// tracks and reading no file. What is heard of each segment that has sound is `clipVolume` times its volume, from
/// its start to its end in the order of the plan, so 0 while the clips are muted: the clip track holds it up to 1
/// and its tap multiplies by what lies above. The music track rises from 0 to the
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
        // Between two volumes set with setVolume the platform ramps from one to the other (blue at 1 then red
        // at 0.5 read blue at 0.375 in compile check run 38658994782), so each segment holds its volume from its
        // start to its end with a ramp that does not change.
        // A volume above 1 is never set on the track: the track holds the volume up to 1, and the tap
        // multiplies each sample by what lies above it.
        var gains: [ClipGains.Piece] = []
        for segment in plan.segments where segment.hasSound {
            let volume = plan.sound.clipVolume * segment.volume
            let held = Float(min(volume, 1))
            clips.setVolumeRamp(
                fromStartVolume: held, toEndVolume: held,
                timeRange: CMTimeRange(
                    start: CMTime(value: segment.timelineStart.ticks, timescale: 600),
                    duration: CMTime(value: segment.duration.ticks, timescale: 600)))
            gains.append(ClipGains.Piece(
                start: Double(segment.timelineStart.ticks) / 600,
                end: Double(segment.timelineStart.ticks + segment.duration.ticks) / 600,
                gain: Float(max(volume, 1))))
        }
        clips.audioTapProcessor = clipGainTap(ClipGains(pieces: gains))
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

/// The gain of each segment with sound past the volume its track holds, from its start to its end on the timeline
/// in seconds: 1 up to a volume of 1, the volume above it.
private final class ClipGains {
    struct Piece {
        let start: Double
        let end: Double
        let gain: Float
    }

    let pieces: [Piece]

    init(pieces: [Piece]) {
        self.pieces = pieces
    }

    /// The gain at a time of the timeline, 1 outside every piece.
    func gain(at seconds: Double) -> Float {
        pieces.first { seconds >= $0.start && seconds < $0.end }?.gain ?? 1
    }
}

/// The tap of the clip track: each sample of the track times the gain of its segment, held between minus 1 and 1.
/// The time of a sample is read from the time range of the source audio of each call. The tap holds the gains
/// and lets them go when the platform ends it. Nil when the platform makes no tap.
///
/// https://developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapcreate(_:_:_:_:)
/// https://developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapcallbacks
/// https://developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapgetsourceaudio(_:_:_:_:_:_:)
/// https://developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapgetstorage(_:)
/// https://developer.apple.com/documentation/avfoundation/avmutableaudiomixinputparameters/audiotapprocessor
private func clipGainTap(_ gains: ClipGains) -> MTAudioProcessingTap? {
    let held = Unmanaged.passRetained(gains).toOpaque()
    var callbacks = MTAudioProcessingTapCallbacks(
        version: kMTAudioProcessingTapCallbacksVersion_0,
        clientInfo: held,
        init: { _, clientInfo, storage in
            storage.pointee = clientInfo
        },
        finalize: { tap in
            Unmanaged<ClipGains>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
        },
        prepare: nil,
        unprepare: nil,
        process: { tap, frames, _, buffers, framesOut, flagsOut in
            var range = CMTimeRange()
            guard MTAudioProcessingTapGetSourceAudio(tap, frames, buffers, flagsOut, &range, framesOut) == noErr
            else { return }
            let gains = Unmanaged<ClipGains>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
            let count = Int(framesOut.pointee)
            guard count > 0 else { return }
            let start = range.start.seconds
            let length = range.duration.seconds
            // The tap's format is float samples, one buffer per channel unless a buffer says it holds more.
            for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
                guard let data = buffer.mData else { continue }
                let channels = max(Int(buffer.mNumberChannels), 1)
                let samples = data.assumingMemoryBound(to: Float.self)
                let total = min(Int(buffer.mDataByteSize) / MemoryLayout<Float>.size, count * channels)
                for index in 0..<total {
                    let gain = gains.gain(at: start + length * Double(index / channels) / Double(count))
                    samples[index] = min(max(samples[index] * gain, -1), 1)
                }
            }
        })
    var tap: MTAudioProcessingTap?
    guard MTAudioProcessingTapCreate(
        kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap) == noErr
    else {
        Unmanaged<ClipGains>.fromOpaque(held).release()
        return nil
    }
    return tap
}

/// The video composition of a plan, for a new item, an export and a refresh alike: one instruction per segment
/// that puts its upright picture at its place on the canvas, its blurred copy at the segment's backdrop when it
/// has one, and holds the texts whose time overlaps it. It names
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
        func onCanvas(_ placement: Placement) -> CGAffineTransform {
            CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(info.height))
                .concatenating(transform(for: placement, width: info.width, height: info.height))
                .concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(plan.height)))
        }
        let made = pieceTexts(of: plan, in: range, kept: kept)
        kept += made.texts
        instructions.append(PieceInstruction(
            timeRange: range, track: track, placing: onCanvas(segment.placement),
            backdrop: segment.backdrop.map(onCanvas), texts: made.texts, drawn: made.drawn))
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
