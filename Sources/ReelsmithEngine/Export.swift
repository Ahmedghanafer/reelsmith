#if canImport(AVFoundation)
import Foundation
import ReelsmithCore

/// Writes an MPEG-4 file, whatever the name of the output place, with H.264 and AAC at 1080 by 1920 and 30 frames.
/// Replaces a file at the output place. The sound ends where the last clip with sound ends, no silence is added
/// after it. Progress goes from 0 to 1 and never goes back.
public func export(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL, to output: URL,
                   progress: @escaping @Sendable (Double) -> Void) async throws {
    throw EngineError.notBuilt
}
#endif
