import ReelsmithCore
import XCTest

final class ProjectTests: XCTestCase {
    private let project = Seed.threeClips.project

    func testStartsComeFromTheClipLengths() {
        XCTAssertEqual(project.start(of: ClipID(1)), Time(ticks: 0))
        XCTAssertEqual(project.start(of: ClipID(2)), Time(ticks: 1800))
        XCTAssertEqual(project.start(of: ClipID(3)), Time(ticks: 4200))
    }

    func testDurationIsTheSumOfTheClipLengths() {
        XCTAssertEqual(project.duration, Time(ticks: 5400))
    }

    func testClipAtAJoinIsTheLaterOneAndNoneAtTheEnd() {
        XCTAssertEqual(project.clip(at: Time(ticks: 1800))?.media, MediaID("red"))
        XCTAssertNil(project.clip(at: Time(ticks: 5400)))
    }

    func testPositionOfTheFirstClipIs1() {
        XCTAssertEqual(project.position(of: ClipID(1)), 1)
    }
}
