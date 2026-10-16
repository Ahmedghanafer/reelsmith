import ReelsmithEngine

/// The state of the media, kept by `Engine` as long as the app runs. Empty until it is built.
final class MediaState {
}

/// The calls of the media: the pickers, the copies and the facts. Each throws `EngineError.notBuilt` until it is
/// built.
extension Engine {
    func readMediaInfo(id: String, fileName: String, folder: String) async throws -> String {
        throw EngineError.notBuilt
    }

    func pick(photos: Bool, limit: Int64) async throws -> Int64 {
        throw EngineError.notBuilt
    }

    func copyPicked(folder: String) async throws -> [String] {
        throw EngineError.notBuilt
    }

    func pickAudio() async throws -> Bool {
        throw EngineError.notBuilt
    }

    func importMusic(folder: String) async throws -> String {
        throw EngineError.notBuilt
    }

    func musicFromVideo(folder: String) async throws -> String {
        throw EngineError.notBuilt
    }
}
