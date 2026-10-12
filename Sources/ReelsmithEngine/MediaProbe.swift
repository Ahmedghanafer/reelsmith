#if canImport(AVFoundation)
import Foundation
import ReelsmithCore

public func readMediaInfo(id: MediaID, fileName: String, in mediaFolder: URL) async throws -> MediaInfo {
    throw EngineError.notBuilt
}
#endif
