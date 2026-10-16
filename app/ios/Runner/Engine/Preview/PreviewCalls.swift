import ReelsmithEngine

/// The state of the preview, kept by `Engine` as long as the app runs. Empty until it is built.
final class PreviewState {
}

/// The calls of the preview. Each throws `EngineError.notBuilt` until the preview is built.
extension Engine {
    func createPreview() throws -> Int64 {
        throw EngineError.notBuilt
    }

    func show(textureId: Int64, project: String, mediaFolder: String, playhead: Int64?, playing: Bool) throws {
        throw EngineError.notBuilt
    }

    func disposePreview(textureId: Int64) throws {
        throw EngineError.notBuilt
    }
}
