import ReelsmithCore
import XCTest

/// Holds the test photo and the seed `photo-wide`.
final class PhotoSeedTests: XCTestCase {
    func testTheTestPhotoMagentaHoldsItsValues() {
        let magenta = TestPhoto.magenta

        XCTAssertEqual(magenta.name, "magenta")
        XCTAssertEqual(magenta.width, 1080)
        XCTAssertEqual(magenta.height, 1440)
        XCTAssertEqual(magenta.colour, RGB(r: 255, g: 0, b: 255))
    }

    func testTheInfoOfATestPhotoIsComputedFromItsOwnValues() {
        var photo = TestPhoto.magenta
        photo.name = "other"
        photo.width = 640
        photo.height = 480

        XCTAssertEqual(TestPhoto.magenta.info, MediaInfo(
            id: MediaID("magenta"), fileName: "magenta.png", width: 1080, height: 1440,
            duration: MediaInfo.photoLongest, quarterTurns: 0, hasSound: false, kind: .photo))
        XCTAssertEqual(photo.info, MediaInfo(
            id: MediaID("other"), fileName: "other.png", width: 640, height: 480,
            duration: MediaInfo.photoLongest, quarterTurns: 0, hasSound: false, kind: .photo))
    }

    func testPhotoWideIsBlueTheMagentaPhotoAndRedOnTheLandscapeCanvas() {
        let seed = Seed.photoWide
        let project = seed.project

        XCTAssertEqual(Seed(rawValue: "photo-wide"), .photoWide)
        XCTAssertEqual(seed.canvas, .landscape)
        XCTAssertEqual(project.canvas, .landscape)
        XCTAssertEqual(seed.testClips, [.blue, .red])
        XCTAssertEqual(seed.testPhotos, [.magenta])
        XCTAssertEqual(project.clips, [
            Clip(id: ClipID(1), media: MediaID("blue"), sourceStart: .zero, duration: Time(ticks: 1800)),
            Clip(id: ClipID(2), media: MediaID("magenta"), sourceStart: .zero, duration: Time(ticks: 1800)),
            Clip(id: ClipID(3), media: MediaID("red"), sourceStart: .zero, duration: Time(ticks: 2400)),
        ])
        XCTAssertEqual(project.nextClipID, 4)
        XCTAssertEqual(project.duration, Time(ticks: 6000))
        XCTAssertEqual(project.media, [
            MediaID("blue"): TestClip.blue.info, MediaID("magenta"): TestPhoto.magenta.info,
            MediaID("red"): TestClip.red.info,
        ])
        XCTAssertEqual(project.fileNames, ["blue.mov", "magenta.png", "red.mov"])
        XCTAssertEqual(project.texts, [])
        XCTAssertNil(project.music)
        XCTAssertNil(seed.selectedText)
        XCTAssertEqual(seed.testTones, [])
        XCTAssertFalse(seed.showsSound)
    }

    func testEveryOtherSeedHasNoTestPhotoAndNoPhoto() {
        for seed in Seed.allCases where seed != .photoWide {
            XCTAssertEqual(seed.testPhotos, [], seed.rawValue)
            for info in seed.project.media.values {
                XCTAssertEqual(info.kind, .video, seed.rawValue)
            }
            for clip in seed.project.clips {
                XCTAssertEqual(clip.volume, 1, seed.rawValue)
            }
        }
    }
}
