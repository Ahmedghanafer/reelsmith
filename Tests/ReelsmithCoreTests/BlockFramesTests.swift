import ReelsmithCore
import XCTest

/// The times a media's frames are made at, and which made frame each tile of a block shows. A tile is 56
/// points, as high as the clip row.
final class BlockFramesTests: XCTestCase {
    /// A video of 30 seconds.
    private let long = MediaInfo(
        id: MediaID("long"), fileName: "long.mov", width: 1920, height: 1080, duration: Time(ticks: 18000),
        quarterTurns: 0, hasSound: false)

    func testBlueIsMadeAt0And600And1200() {
        XCTAssertEqual(BlockFrames.times(of: TestClip.blue.info), [0, 600, 1200].map { Time(ticks: $0) })
    }

    func testAPhotoIsMadeAtZeroAlone() {
        XCTAssertEqual(BlockFrames.times(of: TestPhoto.magenta.info), [Time.zero])
    }

    func testAMediaOf30SecondsIsMade30TimesOneASecond() {
        let times = BlockFrames.times(of: long)
        XCTAssertEqual(times.count, 30)
        XCTAssertEqual(times.first, Time.zero)
        XCTAssertEqual(times.last, Time(ticks: 17400))
    }

    func testTilesCoverTheWidth() {
        XCTAssertEqual(BlockFrames.tileCount(width: 180, tile: 56), 4)
        XCTAssertEqual(BlockFrames.tileCount(width: 240, tile: 56), 5)
        XCTAssertEqual(BlockFrames.tileCount(width: 112, tile: 56), 2)
        XCTAssertEqual(BlockFrames.tileCount(width: 0, tile: 56), 0)
    }

    func testATileShowsTheMadeTimeNearestTheSourceTimeUnderItsLeftEdge() {
        let clip = Clip(id: ClipID(1), media: long.id, sourceStart: Time(ticks: 600), duration: Time(ticks: 6000))
        // 112 points are 1120 ticks: 600 plus 1120 is 1720, nearest 1800.
        XCTAssertEqual(frameTime(clip, long, tile: 2), Time(ticks: 1800))
        // 56 points are 560 ticks: 600 plus 560 is 1160, nearest 1200.
        XCTAssertEqual(frameTime(clip, long, tile: 1), Time(ticks: 1200))
        XCTAssertEqual(frameTime(clip, long, tile: 0), Time(ticks: 600))
    }

    func testATileNeverShowsPastTheLastMadeTime() {
        let blue = TestClip.blue
        let clip = Clip(id: ClipID(1), media: blue.info.id, sourceStart: Time(ticks: 600), duration: Time(ticks: 1200))
        // 600 plus 4 tiles of 560 ticks is 2840, past 1200, the last made.
        XCTAssertEqual(frameTime(clip, blue.info, tile: 4), Time(ticks: 1200))
        XCTAssertEqual(frameTime(clip, long, tile: 40), Time(ticks: 17400))
    }

    func testEveryTileOfAPhotoShowsItsOneFrame() {
        let photo = TestPhoto.magenta.info
        let clip = Clip(id: ClipID(1), media: photo.id, sourceStart: .zero, duration: MediaInfo.photoLength)
        for tile in 0..<4 {
            XCTAssertEqual(frameTime(clip, photo, tile: tile), Time.zero)
        }
    }

    private func frameTime(_ clip: Clip, _ media: MediaInfo, tile: Int) -> Time {
        BlockFrames.frameTime(of: clip, media: media, tile: tile, tile: 56, scale: .standard)
    }
}
