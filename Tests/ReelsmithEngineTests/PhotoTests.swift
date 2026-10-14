#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// Photos in the picture, the cover and the export, drawn by the compositor from the plan. Every plan is on the
/// landscape canvas at 1080p and 30, where the photo of 1080 by 1440 fills x 555 to 1365. The clips, the photo and
/// what is made go into the folder of `ExportTests`. A share is the part of the pixels of a rectangle, counted from
/// the top left, within 24 per channel of a colour (rule 8).
final class PhotoTests: XCTestCase {
    /// What one plan gave as an item, an export and a cover.
    struct Made {
        var name: String
        var expected: Int64
        var itemTicks: Int64
        var compositionTicks: Int64
        var itemMagenta: Double
        var export: URL
        var exportTicks: Int64
        var frames: Int
        var exportMagenta: Double
        var cover: URL
        var coverWidth: Int
        var coverHeight: Int
    }

    /// The four plans of E19, each made once for the tests that read it. The photo stands at 4.5 seconds in each:
    /// in the last two it is 3600 ticks long.
    static let photoWide = Task<Made, Error> { @MainActor in
        try await made(Seed.photoWide.project, name: "photo-wide", expected: 6000)
    }
    static let blueThenPhoto = Task<Made, Error> { @MainActor in
        try await made(project([(TestClip.blue.info, 1800), (photo, 1800)]), name: "blue-then-photo", expected: 3600)
    }
    static let photoAlone = Task<Made, Error> { @MainActor in
        try await made(project([(photo, 3600)]), name: "photo-alone", expected: 3600)
    }
    static let photoThenBlue = Task<Made, Error> { @MainActor in
        try await made(project([(photo, 3600), (TestClip.blue.info, 1800)]), name: "photo-then-blue", expected: 5400)
    }

    // 1. E19: every plan gives an item, an export and a cover of its length, the photo drawn over the empty range.
    func testE19EachOfTheFourPlansGivesAnItemAnExportAndACoverOfItsLengthWithThePhotoDrawn() async throws {
        let plans = [
            ("photo-wide", Self.photoWide), ("blue-then-photo", Self.blueThenPhoto),
            ("photo-alone", Self.photoAlone), ("photo-then-blue", Self.photoThenBlue),
        ]
        for (name, task) in plans {
            let made: Made
            do {
                made = try await task.value
            } catch {
                print("E19: \(name) refused: \(error)")
                XCTFail("\(name) refused: \(error)")
                continue
            }
            XCTAssertEqual(made.itemTicks, made.expected, name + " item")
            XCTAssertEqual(made.compositionTicks, made.expected, name + " composition")
            XCTAssertEqual(made.exportTicks, made.expected, name + " export")
            XCTAssertEqual(made.frames, Int(made.expected / 20), name + " frames")
            XCTAssertGreaterThan(made.itemMagenta, 0.9, name + " magenta in the item at 4.5 seconds")
            XCTAssertGreaterThan(made.exportMagenta, 0.9, name + " magenta in the export at 4.5 seconds")
            XCTAssertEqual(max(made.coverWidth, made.coverHeight), 360, name + " cover")
        }
    }

    // 2. The export of photo-wide.
    func testTheExportOfPhotoWideIs6000TicksAnd300FramesBlueThenThePhotoThenRed() async throws {
        let made = try await Self.photoWide.value
        XCTAssertEqual(made.exportTicks, 6000)
        XCTAssertEqual(made.frames, 300)
        let photoTime = try await frame(of: AVURLAsset(url: made.export), composition: nil, at: 2700)
        XCTAssertGreaterThan(try share(of: magenta, in: photoTime, photoPlace), 0.9, "the photo's place at 4.5")
        XCTAssertGreaterThan(try share(of: black, in: photoTime, besidePhoto), 0.9, "x 200 at 4.5")
        let blueTime = try await frame(of: AVURLAsset(url: made.export), composition: nil, at: 900)
        XCTAssertGreaterThan(try share(of: blue, in: blueTime, middle), 0.9, "the middle at 1.5")
        let redTime = try await frame(of: AVURLAsset(url: made.export), composition: nil, at: 4200)
        XCTAssertGreaterThan(try share(of: red, in: redTime, middle), 0.9, "the middle at 7")
    }

    // 3. The photo last.
    func testTheExportOfBlueThenThePhotoIs3600TicksAnd180FramesMagentaAt4Point5() async throws {
        let made = try await Self.blueThenPhoto.value
        XCTAssertEqual(made.exportTicks, 3600)
        XCTAssertEqual(made.frames, 180)
        XCTAssertGreaterThan(made.exportMagenta, 0.9)
    }

    // 5. The cover of a plan whose first segment is the photo.
    func testTheCoverOfThePhotoThenBlueIs360OnItsLongSideAndMagentaInTheMiddle() async throws {
        let made = try await Self.photoThenBlue.value
        XCTAssertEqual(max(made.coverWidth, made.coverHeight), 360)
        let cover = try picture(of: made.cover)
        let centre = CGRect(x: cover.width / 2 - 10, y: cover.height / 2 - 10, width: 20, height: 20)
        XCTAssertGreaterThan(try share(of: magenta, in: cover, centre), 0.9)
    }

    // 6. A text added to an item of photo-wide, drawn with no file read.
    @MainActor
    func testRefreshPictureOfAnItemOfPhotoWideWithATextAddedSucceedsAndKeepsThePhoto() async throws {
        let made = try await Self.photoWide.value
        XCTAssertEqual(made.itemTicks, 6000, "the item of photo-wide")
        var project = Seed.photoWide.project
        let item = try await makePlayerItem(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
        project.texts = [
            TextItem(id: TextID(1), string: "TOP", span: .whole, x: 960, y: 100, rotation: 0, style: .standard),
        ]
        project.nextTextID = 2
        try refreshPicture(of: item, plan: renderPlan(for: project), media: project.media)
        let photoTime = try await frame(of: item.asset, composition: item.videoComposition, at: 2700)
        XCTAssertGreaterThan(try share(of: magenta, in: photoTime, photoPlace), 0.9, "the photo's place at 4.5")
    }

    // 8. The sound of photo-wide: the clips over blue and red, nothing over the photo.
    func testTheSoundOfPhotoWideIs440OverBlueAndRedAndSilentOverThePhoto() async throws {
        let file = try await Self.photoWide.value.export
        let overBlue = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 600), to: Time(ticks: 1200))
        let overPhoto = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 2100), to: Time(ticks: 3300))
        let overRed = try await toneLevel(of: file, hertz: 440, from: Time(ticks: 4200), to: Time(ticks: 4800))
        XCTAssertEqual(overBlue, 0.5, accuracy: 0.075, "440 Hz over blue")
        XCTAssertLessThan(overPhoto, 0.02, "440 Hz over the photo")
        XCTAssertEqual(overRed, 0.5, accuracy: 0.075, "440 Hz over red")
    }

    /// Writes the clips and the photo, then makes the item, the export and the cover of the plan of the project and
    /// prints one line that starts with `E19:`.
    @MainActor
    static func made(_ project: Project, name: String, expected: Int64) async throws -> Made {
        let folder = ExportTests.folder
        for clip in [TestClip.blue, TestClip.red] {
            _ = try await writeTestClip(clip, to: folder)
        }
        try writeMagentaForNow(to: folder)
        let plan = try renderPlan(for: project)

        let item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: folder)
        let compositionTicks = ticks(try await item.asset.load(.duration))
        let itemFrame = try await frame(of: item.asset, composition: item.videoComposition, at: 2700)
        let itemMagenta = try share(of: magenta, in: itemFrame, photoPlace)
        let ready = try await readyTicks(of: item)

        let output = folder.appendingPathComponent("photo-\(name).mp4")
        try await export(plan: plan, media: project.media, mediaFolder: folder, to: output) { _ in }
        let pictureTrack = try await tracks(of: output).first { $0.kind == "vide" }
        let exportTicks = pictureTrack.map { ticks($0.duration) } ?? -1
        let frames = try await frameCount(of: output)
        let exportFrame = try await frame(of: AVURLAsset(url: output), composition: nil, at: 2700)
        let exportMagenta = try share(of: magenta, in: exportFrame, photoPlace)

        let cover = folder.appendingPathComponent("photo-\(name).cover.jpg")
        try await writeCover(plan: plan, media: project.media, mediaFolder: folder, to: cover)
        let coverPicture = try picture(of: cover)

        print("E19: \(name) item \(ready.ticks) ticks (\(ready.status)), composition \(compositionTicks) ticks, "
            + "export \(exportTicks) ticks and \(frames) frames, magenta at 4.5 seconds \(itemMagenta) in the item "
            + "and \(exportMagenta) in the export, cover \(coverPicture.width) by \(coverPicture.height), "
            + "expected \(expected) ticks")
        return Made(
            name: name, expected: expected, itemTicks: ready.ticks, compositionTicks: compositionTicks,
            itemMagenta: itemMagenta, export: output, exportTicks: exportTicks, frames: frames,
            exportMagenta: exportMagenta, cover: cover, coverWidth: coverPicture.width,
            coverHeight: coverPicture.height)
    }

    /// The length of the item once a player has it ready, -1 when it never is, with the status in words.
    /// Waits up to 30 seconds and prints the seconds it waited, expected within 10.
    /// https://developer.apple.com/documentation/avfoundation/avplayeritem/duration
    @MainActor
    static func readyTicks(of item: AVPlayerItem) async throws -> (ticks: Int64, status: String) {
        let player = AVPlayer(playerItem: item)
        let began = Date()
        while item.status == .unknown && Date().timeIntervalSince(began) < 30 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        print("E19: waited \(Date().timeIntervalSince(began)) seconds for the item, expected within 10")
        withExtendedLifetime(player) {}
        guard item.status == .readyToPlay else {
            return (-1, "status \(item.status.rawValue), error \(String(describing: item.error))")
        }
        return (ticks(item.duration), "ready")
    }

    /// Until the Engine writes the photo: the magenta photo as a PNG, kept when it is there.
    static func writeMagentaForNow(to folder: URL) throws {
        let file = folder.appendingPathComponent("magenta.png")
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let colour = try XCTUnwrap(CIColor(red: 1, green: 0, blue: 1, alpha: 1, colorSpace: space))
        let image = CIImage(color: colour).cropped(to: CGRect(x: 0, y: 0, width: 1080, height: 1440))
        try CIContext().writePNGRepresentation(of: image, to: file, format: .RGBA8, colorSpace: space)
    }
}

private let photo = TestPhoto.magenta.info
private let magenta = RGB(r: 255, g: 0, b: 255)
private let blue = RGB(r: 0, g: 0, b: 255)
private let red = RGB(r: 255, g: 0, b: 0)
private let black = RGB(r: 0, g: 0, b: 0)

/// The photo's place, x 555 to 1365, over its middle 200 rows.
private let photoPlace = CGRect(x: 555, y: 440, width: 810, height: 200)
/// Around x 200, in a side bar beside the photo.
private let besidePhoto = CGRect(x: 190, y: 530, width: 20, height: 20)
/// The middle of the canvas, inside the place of every clip.
private let middle = CGRect(x: 860, y: 440, width: 200, height: 200)

/// A landscape project of the media in their order, each from its start for its ticks.
private func project(_ pieces: [(MediaInfo, Int64)]) -> Project {
    var project = Project(canvas: .landscape)
    for (info, length) in pieces {
        project.media[info.id] = info
        project.clips.append(
            Clip(id: ClipID(project.nextClipID), media: info.id, sourceStart: .zero, duration: Time(ticks: length)))
        project.nextClipID += 1
    }
    return project
}

private func ticks(_ time: CMTime) -> Int64 {
    time.convertScale(600, method: .roundHalfAwayFromZero).value
}

/// The frame shown at a time, through the video composition when one is given.
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
private func frame(of asset: AVAsset, composition: AVVideoComposition?, at ticks: Int64) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.videoComposition = composition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try await generator.image(at: CMTime(value: ticks, timescale: 600)).image
}

/// A picture file read whole by Core Image.
/// https://developer.apple.com/documentation/coreimage/ciimage/init(contentsof:)
/// https://developer.apple.com/documentation/coreimage/cicontext/createcgimage(_:from:)
private func picture(of file: URL) throws -> CGImage {
    let image = try XCTUnwrap(CIImage(contentsOf: file), "Core Image cannot read \(file.lastPathComponent)")
    return try XCTUnwrap(CIContext().createCGImage(image, from: image.extent))
}

/// The share of the pixels of the rectangle, counted from the top left, within 24 per channel of the colour.
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
private func share(of colour: RGB, in image: CGImage, _ rect: CGRect) throws -> Double {
    guard rect.minX >= 0, rect.minY >= 0, Int(rect.maxX) <= image.width, Int(rect.maxY) <= image.height else {
        XCTFail("\(rect) lies outside the picture of \(image.width) by \(image.height)")
        return 0
    }
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
    var near = 0
    var all = 0
    for y in Int(rect.minY)..<Int(rect.maxY) {
        for x in Int(rect.minX)..<Int(rect.maxX) {
            let offset = y * context.bytesPerRow + x * 4
            let worst = max(
                abs(Int(bytes[offset]) - Int(colour.r)), abs(Int(bytes[offset + 1]) - Int(colour.g)),
                abs(Int(bytes[offset + 2]) - Int(colour.b)))
            if worst <= 24 {
                near += 1
            }
            all += 1
        }
    }
    return Double(near) / Double(all)
}
#endif
