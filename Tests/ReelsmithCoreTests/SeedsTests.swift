import ReelsmithCore
import XCTest

final class SeedsTests: XCTestCase {
    func testTheFiveTestClipsHoldTheValuesOfTheTable() {
        let blue = RGB(r: 0, g: 0, b: 255)
        let red = RGB(r: 255, g: 0, b: 0)
        let green = RGB(r: 0, g: 255, b: 0)
        let white = RGB(r: 255, g: 255, b: 255)
        let yellow = RGB(r: 255, g: 255, b: 0)

        XCTAssertEqual(TestClip.blue, TestClip(
            name: "blue", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 1800), framesPerSecond: 30,
            quarterTurns: 0, hasSound: true, left: blue, right: blue))
        XCTAssertEqual(TestClip.red, TestClip(
            name: "red", storedWidth: 1080, storedHeight: 1920, duration: Time(ticks: 2400), framesPerSecond: 30,
            quarterTurns: 0, hasSound: true, left: red, right: red))
        XCTAssertEqual(TestClip.green, TestClip(
            name: "green", storedWidth: 1080, storedHeight: 1920, duration: Time(ticks: 1200), framesPerSecond: 30,
            quarterTurns: 0, hasSound: false, left: green, right: green))
        XCTAssertEqual(TestClip.turned, TestClip(
            name: "turned", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 1200), framesPerSecond: 30,
            quarterTurns: 1, hasSound: false, left: white, right: blue))
        XCTAssertEqual(TestClip.fast, TestClip(
            name: "fast", storedWidth: 1080, storedHeight: 1920, duration: Time(ticks: 1200), framesPerSecond: 60,
            quarterTurns: 0, hasSound: false, left: yellow, right: yellow))
        XCTAssertEqual(TestClip.all, [.blue, .red, .green, .turned, .fast])
    }

    func testInfoGivesEachClipTheIdAndTheFileOfItsName() {
        XCTAssertEqual(TestClip.all.map(\.info.id.raw), ["blue", "red", "green", "turned", "fast"])
        XCTAssertEqual(
            TestClip.all.map(\.info.fileName), ["blue.mov", "red.mov", "green.mov", "turned.mov", "fast.mov"])
        XCTAssertEqual(TestClip.turned.info, MediaInfo(
            id: MediaID("turned"), fileName: "turned.mov", width: 1920, height: 1080, duration: Time(ticks: 1200),
            quarterTurns: 1, hasSound: false))
    }

    func testTheEmptySeedHasNoClips() {
        XCTAssertEqual(Seed.empty.testClips, [])
        XCTAssertEqual(Seed.empty.project.clips, [])
    }

    func testTwoClipsIsBlueThenRed() {
        XCTAssertEqual(Seed.twoClips.testClips, [.blue, .red])
        XCTAssertEqual(Seed.twoClips.project.clips.map(\.media), [MediaID("blue"), MediaID("red")])
        XCTAssertEqual(Seed.twoClips.project.duration, Time(ticks: 4200))
    }

    func testThreeClipsIsBlueRedGreen() {
        XCTAssertEqual(Seed.threeClips.testClips, [.blue, .red, .green])
        XCTAssertEqual(
            Seed.threeClips.project.clips.map(\.media), [MediaID("blue"), MediaID("red"), MediaID("green")])
        XCTAssertEqual(Seed.threeClips.project.duration, Time(ticks: 5400))
    }

    func testAnUnknownSeedNameAnswersNil() {
        XCTAssertNil(Seed(rawValue: "four-clips"))
    }

    func testSeedProjectsCountTheirClipIdsFrom1() {
        XCTAssertEqual(Seed.empty.project.nextClipID, 1)
        XCTAssertEqual(Seed.twoClips.project.clips.map(\.id), [ClipID(1), ClipID(2)])
        XCTAssertEqual(Seed.twoClips.project.nextClipID, 3)
        XCTAssertEqual(Seed.threeClips.project.clips.map(\.id), [ClipID(1), ClipID(2), ClipID(3)])
        XCTAssertEqual(Seed.threeClips.project.nextClipID, 4)
    }
}
