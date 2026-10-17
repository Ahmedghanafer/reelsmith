import AVFoundation
import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The state of the preview, kept by `Engine` as long as the app runs: the player of the one preview,
/// from `createPreview` until `disposePreview`. It is made at the start of the app, and sets the audio
/// session there.
final class PreviewState {
    var player: PreviewPlayer?

    // The sound plays with the ring switch on silent and stops other sound of the phone. A failure is logged,
    // and the app goes on with the category it has.
    // https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:)
    // https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            NSLog("%@", "audio session: the category playback was not set: \(error)")
        }
    }
}

/// The calls of the preview. Flutter calls them on the main thread. A `show` or a `disposePreview` for a
/// texture that is not the preview's does nothing.
///
/// https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)
/// https://developer.apple.com/documentation/foundation/jsondecoder
extension Engine {
    /// Makes the player of the preview and its texture, and gives the texture's id. A preview made
    /// before is let go first.
    func createPreview() throws -> Int64 {
        MainActor.assumeIsolated {
            preview.player?.dispose()
            let player = PreviewPlayer(textures: registrar.textures(), events: events)
            preview.player = player
            return player.textureId
        }
    }

    /// The project is the JSON of a project, as the `project` member of the draft JSON holds it. A project
    /// that cannot be read throws.
    func show(textureId: Int64, project: String, mediaFolder: String, playhead: Int64?, playing: Bool) throws {
        let shown = try JSONDecoder().decode(Project.self, from: Data(project.utf8))
        MainActor.assumeIsolated {
            guard let player = preview.player, player.textureId == textureId else {
                return
            }
            player.show(
                project: shown, mediaFolder: URL(fileURLWithPath: mediaFolder),
                playhead: playhead.map { Time(ticks: $0) }, playing: playing)
        }
    }

    func disposePreview(textureId: Int64) throws {
        MainActor.assumeIsolated {
            guard let player = preview.player, player.textureId == textureId else {
                return
            }
            player.dispose()
            preview.player = nil
        }
    }
}
