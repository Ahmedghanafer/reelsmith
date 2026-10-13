#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The three time functions on a player with no app around it. The item is the one of two-clips-wide:
/// blue to 1800 ticks, then red. The clips go into the folder of `ExportTests`.
///
/// https://developer.apple.com/documentation/avfoundation/avplayer/init(playeritem:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/currenttime()
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/status-swift.property
final class PlayerTimeTests: XCTestCase {
    @MainActor
    func testAnExactSeekReportsTrueOnTheMainThreadAndStandsOnTheFrameOfItsTime() async throws {
        let item = try await wideItem()
        let player = try await readyPlayer(with: item)
        let seen = Seen()

        player.seekExactly(to: Time(ticks: 1800)) { finished in
            seen.onMain.append(Thread.isMainThread)
            seen.ended.append(finished)
        }
        try await wait("the seek to 1800 ticks ended", expected: 5) { seen.ended.count == 1 }
        XCTAssertEqual(seen.ended, [true])
        XCTAssertEqual(player.currentTime(), ticks(1800))
        let atJoin = try await middle(of: item, at: player.currentTime())
        XCTAssertLessThanOrEqual(worst(atJoin, RGB(r: 255, g: 0, b: 0)), 24, "at 1800 ticks reads \(atJoin)")

        player.seekExactly(to: Time(ticks: 1780)) { finished in
            seen.onMain.append(Thread.isMainThread)
            seen.ended.append(finished)
        }
        try await wait("the seek to 1780 ticks ended", expected: 5) { seen.ended.count == 2 }
        XCTAssertEqual(seen.ended, [true, true])
        XCTAssertEqual(seen.onMain, [true, true])
        XCTAssertEqual(player.currentTime(), ticks(1780))
        let beforeJoin = try await middle(of: item, at: player.currentTime())
        XCTAssertLessThanOrEqual(worst(beforeJoin, RGB(r: 0, g: 0, b: 255)), 24, "at 1780 ticks reads \(beforeJoin)")
    }

    @MainActor
    func testASeekThatAnotherSeekOvertakesReportsFalse() async throws {
        let player = try await readyPlayer(with: try await wideItem())
        let seen = Seen()

        player.seekExactly(to: Time(ticks: 600)) { finished in
            seen.first = finished
        }
        player.seekExactly(to: Time(ticks: 3000)) { finished in
            seen.second = finished
        }
        try await wait("both seeks ended", expected: 5) { seen.first != nil && seen.second != nil }
        XCTAssertEqual(seen.first, false)
        XCTAssertEqual(seen.second, true)
        XCTAssertEqual(player.currentTime(), ticks(3000))
    }

    @MainActor
    func testASeekWithNoReportMovesThePlayerToTheSameTime() async throws {
        let player = try await readyPlayer(with: try await wideItem())
        XCTAssertEqual(player.currentTime(), ticks(0))

        player.seekExactly(to: Time(ticks: 3000))
        try await wait("the player stands on 3000 ticks", expected: 5) { player.currentTime() == self.ticks(3000) }
    }

    /// A time between two ticks shows the rounding: 1801 thousandths of a second are 1080.6 ticks.
    /// https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)
    @MainActor
    func testAReportIsThePlayersTimeRoundedTowardZeroToATick() async throws {
        let player = try await readyPlayer(with: try await wideItem())
        let seen = Seen()
        let observer = player.reportTime(every: Time.frame) { time in
            seen.times.append(time)
        }

        let landed = await player.seek(
            to: CMTime(value: 1801, timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
        XCTAssertTrue(landed)
        do {
            try await wait("a report came for the jump", expected: 5) { seen.times.contains(Time(ticks: 1080)) }
        } catch {
            XCTFail("no report of 1080 ticks, the reports in ticks: \(seen.times.map { $0.ticks })")
        }
        XCTAssertFalse(seen.times.contains(Time(ticks: 1081)), "\(seen.times.map { $0.ticks })")
        player.removeTimeObserver(observer)
    }

    /// https://developer.apple.com/documentation/avfoundation/avplayer/play()
    /// https://developer.apple.com/documentation/avfoundation/avplayer/pause()
    /// https://developer.apple.com/documentation/avfoundation/avplayer/removetimeobserver(_:)
    @MainActor
    func testAPlayingPlayerReportsItsTimeOnTheMainThreadUntilTheObserverIsRemoved() async throws {
        let player = try await readyPlayer(with: try await wideItem())
        let seen = Seen()
        let observer = player.reportTime(every: Time.frame) { time in
            seen.onMain.append(Thread.isMainThread)
            seen.times.append(time)
            // The player has not gone back since the report was made, so its time is not before the report.
            seen.playerTimes.append(player.currentTime().convertScale(600, method: .roundTowardZero).value)
        }

        player.play()
        do {
            try await wait("ten reports came while playing", expected: 5) { seen.times.count >= 10 }
        } catch {
            XCTFail("the player gave \(seen.times.count) reports, its time is \(player.currentTime().seconds) seconds, "
                + "its rate \(player.rate), its item error \(String(describing: player.currentItem?.error))")
        }
        player.removeTimeObserver(observer)
        let reports = seen.times.map { $0.ticks }
        print("player time: the reports while playing, in ticks: \(reports)")

        XCTAssertFalse(seen.onMain.contains(false))
        XCTAssertEqual(reports, reports.sorted(), "the reports go forward")
        XCTAssertGreaterThan(reports.last ?? 0, reports.first ?? 0, "the reports move")
        for (report, playerTime) in zip(reports, seen.playerTimes) {
            XCTAssertLessThanOrEqual(report, playerTime)
        }

        // The player still plays. A report now is a fault.
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(seen.times.count, reports.count, "a report came after the observer was removed")
        XCTAssertEqual(player.rate, 1)
        player.pause()
    }

    /// What the handlers of one test saw.
    @MainActor
    private final class Seen {
        var ended: [Bool] = []
        var onMain: [Bool] = []
        var first: Bool?
        var second: Bool?
        var times: [Time] = []
        var playerTimes: [Int64] = []
    }

    private struct GaveUp: Error {
        var what: String
    }

    /// Looks every hundredth of a second. Prints the seconds it waited and gives up only at three times the
    /// expected seconds.
    @MainActor
    private func wait(_ what: String, expected: Double, until done: @MainActor () -> Bool) async throws {
        let started = Date()
        while !done() && Date().timeIntervalSince(started) < expected * 3 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let waited = Date().timeIntervalSince(started)
        print("player time: waited \(waited) seconds until \(what), expected within \(expected)")
        if !done() {
            throw GaveUp(what: "not within \(expected * 3) seconds: \(what)")
        }
    }

    @MainActor
    private func wideItem() async throws -> AVPlayerItem {
        for clip in Seed.twoClipsWide.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        let project = Seed.twoClipsWide.project
        return try await makePlayerItem(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
    }

    /// A seek with a completion handler needs an item that is ready.
    @MainActor
    private func readyPlayer(with item: AVPlayerItem) async throws -> AVPlayer {
        let player = AVPlayer(playerItem: item)
        do {
            try await wait("the item is ready", expected: 10) { item.status != .unknown }
        } catch {
            XCTFail("the item never left the status unknown, the player's error: \(String(describing: player.error))")
            throw error
        }
        XCTAssertEqual(item.status, .readyToPlay, "the item's error: \(String(describing: item.error))")
        return player
    }

    private func ticks(_ value: Int64) -> CMTime {
        CMTime(value: value, timescale: 600)
    }

    /// The colour in the middle of the frame the item shows at a time.
    /// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
    /// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
    /// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
    @MainActor
    private func middle(of item: AVPlayerItem, at time: CMTime) async throws -> RGB {
        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.videoComposition = item.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: time).image
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (image.height / 2) * context.bytesPerRow + (image.width / 2) * 4
        return RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
    }
}

/// The largest difference of the three channels.
private func worst(_ colour: RGB, _ wanted: RGB) -> Int {
    max(abs(Int(colour.r) - Int(wanted.r)), abs(Int(colour.g) - Int(wanted.g)), abs(Int(colour.b) - Int(wanted.b)))
}
#endif
