import ReelsmithCore
import XCTest

final class StartStateTests: XCTestCase {
    func testIdleGivesNoWords() {
        XCTAssertNil(StartState.idle.words)
    }

    func testCopyingGivesTheKeyOfCopying() {
        XCTAssertEqual(StartState.copying.words, Words("start.copying"))
    }

    func testFailedGivesTheKeyOfNoneReadable() {
        XCTAssertEqual(StartState.failed.words, Words("start.noneReadable"))
    }

    func testReadyCarriesTheProjectToOpenAndGivesNoWords() {
        let project = Seed.twoClips.project

        guard case .ready(let carried) = StartState.ready(project) else {
            return XCTFail("not ready")
        }
        XCTAssertEqual(carried, project)
        XCTAssertNil(StartState.ready(project).words)
    }

    func testAllWordsListsExactlyTheTwoKeys() {
        XCTAssertEqual(StartState.allWords, ["start.copying", "start.noneReadable"])
    }

    func testAPickerClosedWithNothingChosenLeavesIdle() {
        XCTAssertEqual(StartState.idle.after(.pickerClosed(chosen: 0)), .idle)
    }

    func testOneOrMoreChosenVideosGiveCopying() {
        XCTAssertEqual(StartState.idle.after(.pickerClosed(chosen: 1)), .copying)
        XCTAssertEqual(StartState.idle.after(.pickerClosed(chosen: 3)), .copying)
    }

    func testCopyingEndsReadyWithTheFactsAddedToAnEmptyProject() {
        let facts = [TestClip.blue.info, TestClip.red.info]
        let wanted = reduce(EditorState(project: Project()), .addClips(facts)).project

        XCTAssertEqual(wanted.clips.count, 2)
        XCTAssertEqual(StartState.copying.after(.copyingEnded(facts)), .ready(wanted))
    }

    func testAVideoThatCouldNotBeReadIsLeftOutWithoutAMessageOfItsOwn() {
        // Two were chosen and the facts of one came back.
        let next = StartState.idle.after(.pickerClosed(chosen: 2)).after(.copyingEnded([TestClip.red.info]))

        guard case .ready(let project) = next else {
            return XCTFail("not ready")
        }
        XCTAssertEqual(project.clips.map { $0.media }, [MediaID("red")])
        XCTAssertNil(next.words)
    }

    func testCopyingEndsFailedWhenNoFactsCouldBeRead() {
        XCTAssertEqual(StartState.copying.after(.copyingEnded([])), .failed)
    }

    func testCopyingEndsFailedWhenTheFactsGiveAnEmptyProject() {
        // Shorter than the shortest clip, so addClips leaves it out.
        var short = TestClip.green.info
        short.duration = Time(ticks: 40)

        XCTAssertEqual(StartState.copying.after(.copyingEnded([short])), .failed)
    }

    func testAnEventWithNoMeaningInACaseLeavesItUnchanged() {
        let facts = [TestClip.blue.info]
        let ready = StartState.ready(Seed.twoClips.project)

        XCTAssertEqual(StartState.idle.after(.copyingEnded(facts)), .idle)
        XCTAssertEqual(StartState.idle.after(.failureConfirmed), .idle)
        XCTAssertEqual(StartState.copying.after(.pickerClosed(chosen: 1)), .copying)
        XCTAssertEqual(StartState.copying.after(.failureConfirmed), .copying)
        XCTAssertEqual(StartState.failed.after(.pickerClosed(chosen: 1)), .failed)
        XCTAssertEqual(StartState.failed.after(.copyingEnded(facts)), .failed)
        XCTAssertEqual(ready.after(.pickerClosed(chosen: 1)), ready)
        XCTAssertEqual(ready.after(.copyingEnded(facts)), ready)
        XCTAssertEqual(ready.after(.failureConfirmed), ready)
    }

    func testConfirmingTheFailedCaseGivesIdle() {
        XCTAssertEqual(StartState.failed.after(.failureConfirmed), .idle)
    }
}
