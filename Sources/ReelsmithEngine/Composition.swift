#if canImport(AVFoundation)
import AVFoundation
import ReelsmithCore

@MainActor
public func makePlayerItem(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL) async throws -> AVPlayerItem {
    throw EngineError.notBuilt
}
#endif
