import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The state of the media, kept by `Engine` as long as the app runs: what the last picks chose, and the picker that
/// shows, since a picker holds its delegate weakly. It is read and written on the main thread.
final class MediaState {
    /// The items of the last `pick`, in the order of choosing, for `copyPicked` and `musicFromVideo`.
    var picked: [NSItemProvider] = []
    /// The file of the last `pickAudio`, for `importMusic`.
    var audio: URL?
    var videoPicker: VideoPicker?
    var audioPicker: AudioPicker?
}

/// The facts of a media. The other calls of the media stand in their own files of this folder, `Picker.swift`
/// (`pick` and `copyPicked`), `AudioPicker.swift` (`pickAudio`) and `MusicImport.swift` (`importMusic` and
/// `musicFromVideo`).
///
/// https://developer.apple.com/documentation/foundation/jsonencoder
extension Engine {
    /// The JSON of the facts of `<folder>/<fileName>` as the Engine's `readMediaInfo` reads them, with sorted keys.
    /// It throws what the Engine throws.
    func readMediaInfo(id: String, fileName: String, folder: String) async throws -> String {
        let info = try await ReelsmithEngine.readMediaInfo(
            id: MediaID(id), fileName: fileName, in: URL(fileURLWithPath: folder))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(info), as: UTF8.self)
    }
}
