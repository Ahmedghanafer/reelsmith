#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore

/// The facts of the file `<media folder>/<file name>`: the picture as stored, the length of the picture track
/// rounded down to a tick, the quarter turns of its stored transform, and whether the file has a sound track.
/// Throws `sourceMissing` with the id when the file is not in the folder, and `cannotRead` when it cannot be
/// opened as a video or has no picture track.
///
/// https://developer.apple.com/documentation/avfoundation/avurlasset
/// https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:)
/// https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading/load(_:)
/// https://developer.apple.com/documentation/avfoundation/avassettrack/naturalsize
/// https://developer.apple.com/documentation/avfoundation/avassettrack/preferredtransform
/// https://developer.apple.com/documentation/avfoundation/avassettrack/timerange
/// https://developer.apple.com/documentation/coremedia/cmtimeconvertscale(_:timescale:method:)
public func readMediaInfo(id: MediaID, fileName: String, in mediaFolder: URL) async throws -> MediaInfo {
    let file = mediaFolder.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: file.path) else { throw EngineError.sourceMissing(id) }

    let asset = AVURLAsset(url: file)
    do {
        let pictureTracks = try await asset.loadTracks(withMediaType: .video)
        guard let picture = pictureTracks.first else { throw EngineError.cannotRead }
        let size = try await picture.load(.naturalSize)
        let transform = try await picture.load(.preferredTransform)
        let range = try await picture.load(.timeRange)
        let soundTracks = try await asset.loadTracks(withMediaType: .audio)

        return MediaInfo(
            id: id, fileName: fileName, width: Int(size.width), height: Int(size.height),
            duration: Time(ticks: wholeTicks(of: range.duration)), quarterTurns: quarterTurns(of: transform),
            hasSound: !soundTracks.isEmpty)
    } catch {
        throw EngineError.cannotRead
    }
}

/// A length in ticks, 600 a second, rounded down.
func wholeTicks(of length: CMTime) -> Int64 {
    CMTimeConvertScale(length, timescale: 600, method: .roundTowardZero).value
}

/// The clockwise quarter turns that show a picture with this stored transform upright.
/// One turn is a 0, b 1, c minus 1, d 0. Two turns are a minus 1, d minus 1. Three turns are b minus 1, c 1.
func quarterTurns(of transform: CGAffineTransform) -> Int {
    if transform.b > 0.5 {
        return 1
    }
    if transform.a < -0.5 {
        return 2
    }
    if transform.b < -0.5 {
        return 3
    }
    return 0
}
#endif
