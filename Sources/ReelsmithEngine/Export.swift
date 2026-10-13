#if canImport(AVFoundation)
import AVFoundation
import Foundation
import ReelsmithCore

/// Writes an MPEG-4 file, whatever the name of the output place, with H.264 and AAC
/// at the size of the plan's canvas (1920 by 1080 or 1080 by 1920) and 30 frames.
/// Replaces a file at the output place. The sound ends where the last clip with sound ends, no silence is added
/// after it. Progress goes from 0 to 1 and never goes back.
///
/// Throws `nothingToExport` for an empty plan, `sourceMissing` for a file that is not in the media folder,
/// `cannotRead` for a file that has no picture or cannot be put into the composition, and `cannotWrite` when
/// the output cannot be written or the export session fails. The file is written under a temporary name beside the output
/// place and renamed when it is whole.
///
/// https://developer.apple.com/documentation/avfoundation/avassetexportsession
/// https://developer.apple.com/documentation/avfoundation/avassetexportpresethighestquality
/// https://developer.apple.com/documentation/avfoundation/avassetexportsession/exportasynchronously(completionhandler:)
/// https://developer.apple.com/documentation/avfoundation/avassetexportsession/progress
public func export(plan: RenderPlan, media: [MediaID: MediaInfo], mediaFolder: URL, to output: URL,
                   progress: @escaping @Sendable (Double) -> Void) async throws {
    guard !plan.segments.isEmpty else { throw EngineError.nothingToExport }
    let folder = output.deletingLastPathComponent()
    guard FileManager.default.isWritableFile(atPath: folder.path) else { throw EngineError.cannotWrite }

    let built = try await buildComposition(plan: plan, media: media, mediaFolder: mediaFolder)
    guard let session = AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetHighestQuality)
    else { throw EngineError.cannotWrite }
    let temporary = folder.appendingPathComponent(UUID().uuidString + ".tmp.mp4")
    session.videoComposition = built.videoComposition
    session.outputFileType = .mp4
    session.outputURL = temporary

    progress(0)
    let watcher = Task {
        var last = 0.0
        while !Task.isCancelled {
            let now = Double(session.progress)
            if now > last && now < 1 {
                last = now
                progress(now)
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        session.exportAsynchronously {
            done.resume()
        }
    }
    watcher.cancel()
    await watcher.value

    do {
        guard session.status == .completed else { throw EngineError.cannotWrite }
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.moveItem(at: temporary, to: output)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw EngineError.cannotWrite
    }
    progress(1)
}
#endif
