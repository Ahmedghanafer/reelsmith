import Flutter
import ReelsmithCore
import ReelsmithEngine

/// The state of the outputs, kept by `Engine` as long as the app runs. The outputs keep none.
final class OutputState {
}

/// The faces of the text panel. The other calls of the outputs stand in their own files of this folder,
/// `Export.swift` (the export and the awake screen), `SaveToPhotos.swift`, `Cover.swift` and `Frames.swift`, and the
/// native question in `Engine/Confirm.swift`.
extension Engine {
    /// The PostScript names of the two bundled faces as the Engine makes them, after any fallback, one space between
    /// them: the line `editor.faceInfo` of a test start, as `App/Editor/EditorScreen.swift` drew it.
    func faceNames() throws -> String {
        faceName(of: .naskh) + " " + faceName(of: .naskhBold)
    }
}
