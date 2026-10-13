#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import ReelsmithCore

/// The player in `Time`: 600 ticks are one second, and the platform's time type stays in this file.
///
/// https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/addperiodictimeobserver(forinterval:queue:using:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/removetimeobserver(_:)
/// https://developer.apple.com/documentation/coremedia/cmtime/convertscale(_:method:)
/// https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)
extension AVPlayer {
    /// Tolerance zero before and after, no report. May be sent before the item is ready.
    @MainActor public func seekExactly(to time: Time) {
        seek(to: CMTime(value: time.ticks, timescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Tolerance zero before and after. `done` gets false when another seek or a new item ended this one.
    @MainActor public func seekExactly(to time: Time, then done: @escaping @MainActor (Bool) -> Void) {
        // The handler can come on any thread.
        seek(
            to: CMTime(value: time.ticks, timescale: 600), toleranceBefore: .zero, toleranceAfter: .zero
        ) { finished in
            Task { @MainActor in
                done(finished)
            }
        }
    }

    /// Reports the player's time, rounded toward zero to a tick, on the main queue. The result goes to
    /// `removeTimeObserver`.
    @MainActor public func reportTime(every interval: Time, _ report: @escaping @MainActor (Time) -> Void) -> Any {
        // The queue is the main queue, so the block runs on the main actor.
        addPeriodicTimeObserver(forInterval: CMTime(value: interval.ticks, timescale: 600), queue: .main) { time in
            MainActor.assumeIsolated {
                report(Time(ticks: time.convertScale(600, method: .roundTowardZero).value))
            }
        }
    }
}
#endif
