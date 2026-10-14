#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// What a written video file holds: the size of its picture and its rate.
public struct VideoFacts: Equatable, Sendable {
    /// The picture as stored.
    public var width: Int
    public var height: Int
    /// The nominal rate of the first picture track, rounded to a whole number.
    public var framesPerSecond: Int

    public init(width: Int, height: Int, framesPerSecond: Int) {
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
    }

    /// "<width> <height> <framesPerSecond>", as "1280 720 60". Digits 0 to 9.
    public var infoText: String {
        "\(width) \(height) \(framesPerSecond)"
    }
}

/// The facts of the first picture track of a file.
/// Throws `cannotRead` for a file that cannot be opened or has no picture track.
///
/// https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:)
/// https://developer.apple.com/documentation/avfoundation/avassettrack/nominalframerate
/// https://developer.apple.com/documentation/avfoundation/avassettrack/naturalsize
public func readVideoFacts(of file: URL) async throws -> VideoFacts {
    let asset = AVURLAsset(url: file)
    // A track does not keep its asset alive.
    defer { withExtendedLifetime(asset) {} }
    do {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw EngineError.cannotRead }
        let (size, rate) = try await track.load(.naturalSize, .nominalFrameRate)
        return VideoFacts(
            width: Int(size.width.rounded()), height: Int(size.height.rounded()),
            framesPerSecond: Int(rate.rounded()))
    } catch {
        throw EngineError.cannotRead
    }
}
#endif
