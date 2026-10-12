#if canImport(AVFoundation)
import Foundation
import ReelsmithCore

/// Writes under a temporary name, then renames to `<folder>/<name>.mov` and returns it.
/// Keeps a file that is already there.
public func writeTestClip(_ clip: TestClip, to folder: URL) async throws -> URL {
    throw EngineError.notBuilt
}
#endif
