import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The music that comes in from the file browser and from a video, moved from `addMusic` of
/// `App/Editor/Sound/MusicPart.swift` and from `App/Editor/Sound/MusicFromVideo.swift`. A file that is refused
/// throws the error of the Engine, which reaches Dart as a `PlatformException` with its code: `protectedFile` for a
/// protected file, so Dart shows the words of a protected file, and every other code for the plain refusal.
/// Nothing is added after a throw.
///
/// https://developer.apple.com/documentation/foundation/jsonencoder
/// https://developer.apple.com/documentation/foundation/filemanager/temporarydirectory
/// https://developer.apple.com/documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)
/// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
/// https://developer.apple.com/documentation/foundation/nsitemprovider/suggestedname
/// https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:)
extension Engine {
    /// Copies the file of the last `pickAudio` into the folder with the Engine's `importMusic`, which holds the
    /// right to read it while it copies, with no title, and gives the JSON of its music file. With no file chosen
    /// it throws `cannotRead`.
    func importMusic(folder: String) async throws -> String {
        guard let source = await MainActor.run(body: { self.media.audio }) else {
            throw EngineError.cannotRead
        }
        let file: MusicFile = try await ReelsmithEngine.importMusic(
            from: source, title: nil, to: URL(fileURLWithPath: folder))
        return try musicJSON(file)
    }

    /// Copies the video of the last `pick` into a new folder under the temporary folder, hands it to the Engine's
    /// `importMusic` with the video's suggested name as the title, which makes the copy the project keeps, and
    /// gives the JSON of its music file. The new folder is removed after an import and after a refusal alike. A
    /// video that cannot be copied, or no video chosen, throws `cannotRead`.
    func musicFromVideo(folder: String) async throws -> String {
        guard let video = await MainActor.run(body: { self.media.picked.first }) else {
            throw EngineError.cannotRead
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // A folder that cannot be made fails the copy below.
        try? FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporary)
        }
        guard let fileName = await copyVideo(video, named: UUID().uuidString, into: temporary) else {
            throw EngineError.cannotRead
        }
        let file: MusicFile = try await ReelsmithEngine.importMusic(
            from: temporary.appendingPathComponent(fileName), title: video.suggestedName ?? "",
            to: URL(fileURLWithPath: folder))
        return try musicJSON(file)
    }

    /// The JSON of a music file with sorted keys, as the draft JSON holds it.
    private func musicJSON(_ file: MusicFile) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(file), as: UTF8.self)
    }
}
