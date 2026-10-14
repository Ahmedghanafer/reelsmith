import ReelsmithCore

public enum EngineError: Error, Equatable {
    case notBuilt
    case sourceMissing(MediaID)
    case cannotRead
    case nothingToExport
    case cannotWrite
    /// A music file that is protected, or cannot go into a composition or an export.
    case protectedFile
}
