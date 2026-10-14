import ReelsmithCore
import XCTest

final class MusicImportTests: XCTestCase {
    private let refusedProtected = MusicImport.Event.refused(isProtected: true)
    private let refusedUnreadable = MusicImport.Event.refused(isProtected: false)

    func testPickedMakesIdleIntoCopying() {
        XCTAssertEqual(MusicImport.idle.after(.picked), .copying)
    }

    func testImportedMakesCopyingIntoIdle() {
        XCTAssertEqual(MusicImport.copying.after(.imported), .idle)
    }

    func testRefusedMakesCopyingIntoFailedWithTheSameFlag() {
        XCTAssertEqual(MusicImport.copying.after(refusedProtected), .failed(isProtected: true))
        XCTAssertEqual(MusicImport.copying.after(refusedUnreadable), .failed(isProtected: false))
    }

    func testFailureConfirmedMakesFailedIntoIdle() {
        XCTAssertEqual(MusicImport.failed(isProtected: true).after(.failureConfirmed), .idle)
        XCTAssertEqual(MusicImport.failed(isProtected: false).after(.failureConfirmed), .idle)
    }

    func testPickedMakesFailedIntoCopying() {
        XCTAssertEqual(MusicImport.failed(isProtected: true).after(.picked), .copying)
        XCTAssertEqual(MusicImport.failed(isProtected: false).after(.picked), .copying)
    }

    func testEveryOtherPairLeavesTheCaseUnchanged() {
        let pairs: [(MusicImport, MusicImport.Event)] = [
            (.idle, .imported), (.idle, refusedProtected), (.idle, refusedUnreadable), (.idle, .failureConfirmed),
            (.copying, .failureConfirmed), (.copying, .picked),
            (.failed(isProtected: true), .imported), (.failed(isProtected: true), refusedUnreadable),
            (.failed(isProtected: true), refusedProtected),
            (.failed(isProtected: false), .imported), (.failed(isProtected: false), refusedProtected),
            (.failed(isProtected: false), refusedUnreadable),
        ]
        for (state, event) in pairs {
            XCTAssertEqual(state.after(event), state, "\(state) after \(event)")
        }
    }

    func testANewPickIsTheWayOutOfARefusal() {
        let next = MusicImport.idle.after(.picked).after(refusedProtected).after(.picked)

        XCTAssertEqual(next, .copying)
        XCTAssertEqual(next.words, Words("music.copying"))
    }

    func testEachCaseGivesItsKeyWithNoArgument() {
        XCTAssertNil(MusicImport.idle.words)
        XCTAssertEqual(MusicImport.copying.words, Words("music.copying", []))
        XCTAssertEqual(MusicImport.failed(isProtected: false).words, Words("music.notReadable", []))
        XCTAssertEqual(MusicImport.failed(isProtected: true).words, Words("music.protected", []))
    }

    func testAllWordsListsTheThreeKeysInOrder() {
        XCTAssertEqual(MusicImport.allWords, ["music.copying", "music.notReadable", "music.protected"])
    }
}
