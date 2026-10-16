import Flutter
import ReelsmithEngine

/// The state of the outputs, kept by `Engine` as long as the app runs. The outputs keep none.
final class OutputState {
}

/// The faces of the text panel. The other calls of the outputs stand in their own files of this folder,
/// `Export.swift` (the export and the awake screen), `SaveToPhotos.swift`, `Cover.swift` and `Frames.swift`, and the
/// native question in `Engine/Confirm.swift`. `faceNames` throws `EngineError.notBuilt` until it is built.
extension Engine {
    func faceNames() throws -> String {
        throw EngineError.notBuilt
    }
}
