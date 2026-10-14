#if canImport(AVFoundation)
import Foundation
import ReelsmithCore

public func writeTestTone(_ tone: TestTone, to folder: URL) async throws -> URL {
    throw EngineError.notBuilt
}
#endif
