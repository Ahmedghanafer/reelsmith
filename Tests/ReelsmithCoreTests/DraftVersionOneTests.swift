import Foundation
import ReelsmithCore
import XCTest

/// Holds that a draft of version 1 stays readable: the literal is the draft of `music-wide` at 4K and 60 with the
/// date 2026-10-14 21:05:09 in UTC, as `encodeDraft` wrote it when the stored form was made. No later story
/// changes the literal, and a story that changes a stored type keeps this test green.
final class DraftVersionOneTests: XCTestCase {
    private let versionOne = #"{"changed":813704709,"exportSettings":{"rate":{"sixty":{}},"size":{"uhd4K":{}}},"project":{"canvas":{"landscape":{}},"clipVolume":1,"clips":[{"duration":{"ticks":1800},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0}},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0}}],"clipsMuted":false,"media":[{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920},{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080}],"music":{"fadeIn":{"ticks":0},"fadeOut":{"ticks":0},"file":{"duration":{"ticks":6000},"fileName":"long-tone.mov","id":{"raw":"long-tone"},"title":"long-tone"},"start":{"ticks":0},"volume":1},"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}"#

    func testTheLiteralOfVersionOneDecodesToTheDraftOfMusicWide() throws {
        let expected = Draft(
            project: Seed.musicWide.project, exportSettings: ExportSettings(size: .uhd4K, rate: .sixty),
            changed: Date(timeIntervalSince1970: 1_792_011_909))

        let draft = try decodeDraft(Data(versionOne.utf8))

        XCTAssertEqual(draft, expected)
        XCTAssertEqual(draft.version, 1)
    }
}
