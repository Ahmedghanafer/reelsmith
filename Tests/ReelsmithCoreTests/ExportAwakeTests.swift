import ReelsmithCore
import XCTest

final class ExportAwakeTests: XCTestCase {
    func testOnlyTheExportingCaseKeepsTheScreenAwakeWhateverThePercent() {
        XCTAssertTrue(ExportState.exporting(percent: 0).keepsScreenAwake)
        XCTAssertTrue(ExportState.exporting(percent: 42).keepsScreenAwake)
        XCTAssertTrue(ExportState.exporting(percent: 100).keepsScreenAwake)
        XCTAssertFalse(ExportState.idle.keepsScreenAwake)
        XCTAssertFalse(ExportState.saved.keepsScreenAwake)
        XCTAssertFalse(ExportState.failed(notAllowed: false).keepsScreenAwake)
        XCTAssertFalse(ExportState.failed(notAllowed: true).keepsScreenAwake)
    }

    func testAlongASavedExportTheScreenIsAwakeFromTheStartToTheSave() {
        let idle = ExportState.idle
        let started = idle.after(.started)
        let half = started.after(.progress(0.5))
        let saved = half.after(.saved)
        let closed = saved.after(.closed)

        XCTAssertEqual(
            [idle, started, half, saved, closed].map(\.keepsScreenAwake), [false, true, true, false, false])
    }

    func testAlongAFailedExportTheScreenIsAwakeFromTheStartToTheFailure() {
        let idle = ExportState.idle
        let started = idle.after(.started)
        let failed = started.after(.failed(notAllowed: false))
        let closed = failed.after(.closed)

        XCTAssertEqual([idle, started, failed, closed].map(\.keepsScreenAwake), [false, true, false, false])
    }
}
