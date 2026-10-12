import ReelsmithCore

public enum EngineError: Error, Equatable {
    case notBuilt
    case sourceMissing(MediaID)
    case cannotRead
    case nothingToExport
    case cannotWrite
}
