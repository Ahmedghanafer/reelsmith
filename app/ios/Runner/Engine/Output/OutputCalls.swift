import Flutter
import ReelsmithEngine

/// The state of the outputs, kept by `Engine` as long as the app runs. Empty until it is built.
final class OutputState {
}

/// The calls of the outputs: the export, the save, the cover, the frames of the blocks, the awake screen, the
/// faces and the native question. Each throws `EngineError.notBuilt` until it is built.
extension Engine {
    func export(project: String, settings: String, mediaFolder: String, fails: Bool) async throws -> ExportedVideo {
        throw EngineError.notBuilt
    }

    func saveToPhotos(file: String) async throws -> SaveOutcome {
        throw EngineError.notBuilt
    }

    func writeCover(project: String, mediaFolder: String, file: String) async throws {
        throw EngineError.notBuilt
    }

    func blockFrames(media: String, mediaFolder: String) async throws -> [Int64: FlutterStandardTypedData] {
        throw EngineError.notBuilt
    }

    func keepAwake(awake: Bool) throws {
        throw EngineError.notBuilt
    }

    func faceNames() throws -> String {
        throw EngineError.notBuilt
    }

    func confirm(question: String, confirmWords: String, cancelWords: String) async throws -> Bool {
        throw EngineError.notBuilt
    }
}
