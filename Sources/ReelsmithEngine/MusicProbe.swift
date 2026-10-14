#if canImport(AVFoundation)
import Foundation
import ReelsmithCore

public func readMusicFile(id: MediaID, fileName: String, title: String, in mediaFolder: URL) async throws -> MusicFile {
    throw EngineError.notBuilt
}

public func importMusic(from source: URL, title: String?, to mediaFolder: URL) async throws -> MusicFile {
    throw EngineError.notBuilt
}

func musicUse(hasSound: Bool, isProtected: Bool, isComposable: Bool, isExportable: Bool) -> EngineError? {
    nil
}
#endif
