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
    /// Blue, red, and the test photo as its picture and its still movie in the folder, written once for every plan.
    static let photoMovie = Task<Void, Error> {
        let folder = ExportTests.folder
        for clip in [TestClip.blue, TestClip.red] {
            _ = try await writeTestClip(clip, to: folder)
        }
        let picture = try writeTestPhoto(.magenta, to: folder)
        if !FileManager.default.fileExists(atPath: folder.appendingPathComponent(photo.fileName).path) {
            _ = try await importPhoto(from: picture, id: photo.id, into: folder)
        }
    }
    static let photoThenBlue = Task<Made, Error> { @MainActor in
        try await made(project([(photo, 3600), (TestClip.blue.info, 1800)]), name: "photo-then-blue", expected: 5400)
    }

    // 1. E19: every plan gives an item, an export and a cover of its length, the photo drawn from its still movie.
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

    // 4. The import: the orientation applied, the long side held at 3840, a file that is no picture refused.
    func testAPhotoTurnedBySixImportsUprightWithRedAtTheTop() async throws {
        let source = try emptyFolder().appendingPathComponent("turned.tif")
        try orientedTIFF().write(to: source)
        let folder = try emptyFolder()
        let info = try await imported(source, id: "turned", into: folder)
        XCTAssertEqual(info.width, 300)
        XCTAssertEqual(info.height, 400)
        assertPhotoFacts(info, id: "turned")
        let movie = folder.appendingPathComponent(info.fileName)
        try await assertStillMovie(movie, width: 300, height: 400, coding: "avc1")
        let written = try await frame(of: AVURLAsset(url: movie), composition: nil, at: 0)
        XCTAssertGreaterThan(try share(of: red, in: written, CGRect(x: 140, y: 40, width: 20, height: 20)), 0.9, "top")
        XCTAssertGreaterThan(
            try share(of: green, in: written, CGRect(x: 140, y: 340, width: 20, height: 20)), 0.9, "bottom")
    }

    func testAPhotoOf6000By4000ImportsAt3840By2560() async throws {
        let source = try emptyFolder().appendingPathComponent("large.jpg")
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let large = CIImage(color: CIColor(red: 0, green: 1, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 6000, height: 4000))
        try CIContext().writeJPEGRepresentation(of: large, to: source, colorSpace: space)
        let folder = try emptyFolder()
        let info = try await imported(source, id: "large", into: folder)
        XCTAssertEqual(info.width, 3840)
        XCTAssertEqual(info.height, 2560)
        assertPhotoFacts(info, id: "large")
        try await assertStillMovie(
            folder.appendingPathComponent(info.fileName), width: 3840, height: 2560, coding: "hvc1")

        // The cover of the movie on the landscape canvas, where it fills 1620 by 1080 in the middle.
        var project = Project(canvas: .landscape)
        project.media[info.id] = info
        project.clips = [Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: MediaInfo.photoLength)]
        project.nextClipID = 2
        let cover = folder.appendingPathComponent("large.cover.jpg")
        try await writeCover(plan: renderPlan(for: project), media: project.media, mediaFolder: folder, to: cover)
        let read = try picture(of: cover)
        let centre = CGRect(x: read.width / 2 - 10, y: read.height / 2 - 10, width: 20, height: 20)
        XCTAssertGreaterThan(try share(of: green, in: read, centre), 0.9, "the middle of the cover")
    }

    /// The photo from 106200 for 1800 ticks, the last 3 seconds of its movie, reaches its second picture.
    @MainActor
    func testThePhotoFromNearTheEndOfItsMovieIsMagentaToItsLastFrame() async throws {
        try await Self.photoMovie.value
        var project = Project(canvas: .landscape)
        project.media[photo.id] = photo
        project.clips = [
            Clip(id: ClipID(1), media: photo.id, sourceStart: Time(ticks: 106200), duration: Time(ticks: 1800)),
        ]
        project.nextClipID = 2
        let item = try await makePlayerItem(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
        let length = try await item.asset.load(.duration)
        XCTAssertEqual(ticks(length), 1800)
        for time: Int64 in [0, 900, 1780] {
            let shown = try await frame(of: item.asset, composition: item.videoComposition, at: time)
            XCTAssertGreaterThan(try share(of: magenta, in: shown, photoPlace), 0.9, "at \(time) ticks")
        }
    }

    func testAFileThatIsNoPictureThrowsCannotReadAndLeavesNothingWritten() async throws {
        let source = try emptyFolder().appendingPathComponent("words.jpg")
        try Data("no picture".utf8).write(to: source)
        let folder = try emptyFolder()
        do {
            _ = try await importPhoto(from: source, id: MediaID("words"), into: folder)
            XCTFail("no error, cannotRead wanted")
        } catch {
            XCTAssertEqual(error as? EngineError, .cannotRead)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    // 5. The cover of a plan whose first segment is the photo.
    func testTheCoverOfThePhotoThenBlueIs360OnItsLongSideAndMagentaInTheMiddle() async throws {
        let made = try await Self.photoThenBlue.value
        XCTAssertEqual(max(made.coverWidth, made.coverHeight), 360)
        let cover = try picture(of: made.cover)
        let centre = CGRect(x: cover.width / 2 - 10, y: cover.height / 2 - 10, width: 20, height: 20)
        XCTAssertGreaterThan(try share(of: magenta, in: cover, centre), 0.9)
    }

    // 7. The test photo.
    func testWriteTestPhotoWritesMagentaPngOf1080By1440IntoAFolderItMakes() throws {
        let folder = try emptyFolder().appendingPathComponent("made")
        let file = try writeTestPhoto(.magenta, to: folder)
        XCTAssertEqual(file, folder.appendingPathComponent("magenta.png"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["magenta.png"])
        let written = try picture(of: file)
        XCTAssertEqual(written.width, 1080)
        XCTAssertEqual(written.height, 1440)
        let whole = CGRect(x: 0, y: 0, width: 1080, height: 1440)
        XCTAssertEqual(try share(of: magenta, in: written, whole, within: 6), 1)
    }

    func testWriteTestPhotoKeepsAFileThatIsThere() throws {
        let folder = try emptyFolder()
        let there = Data("kept".utf8)
        try there.write(to: folder.appendingPathComponent("magenta.png"))
        let file = try writeTestPhoto(.magenta, to: folder)
        XCTAssertEqual(try Data(contentsOf: file), there)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["magenta.png"])
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

    /// Writes the clips and the photo's movie, then makes the item, the export and the cover of the plan of the project and
    /// prints one line that starts with `E19:`.
    @MainActor
    static func made(_ project: Project, name: String, expected: Int64) async throws -> Made {
        let folder = ExportTests.folder
        try await photoMovie.value
        let plan = try renderPlan(for: project)

        let output = folder.appendingPathComponent("photo-\(name).mp4")
        let cover = folder.appendingPathComponent("photo-\(name).cover.jpg")
        // A step that throws leaves -1 and its error in the printed line, and the steps after it still run.
        var made = Made(
            name: name, expected: expected, itemTicks: -1, compositionTicks: -1, itemMagenta: -1, export: output,
            exportTicks: -1, frames: -1, exportMagenta: -1, cover: cover, coverWidth: -1, coverHeight: -1)
        var errors: [String] = []

        do {
            let item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: folder)
            made.compositionTicks = ticks(try await item.asset.load(.duration))
            do {
                let itemFrame = try await frame(of: item.asset, composition: item.videoComposition, at: 2700)
                made.itemMagenta = try share(of: magenta, in: itemFrame, photoPlace)
            } catch {
                errors.append("the frame of the item: \(error)")
            }
            let ready = try await readyTicks(of: item)
            made.itemTicks = ready.ticks
            if ready.ticks < 0 {
                errors.append("the item: \(ready.status)")
            }
        } catch {
            errors.append("the item: \(error)")
        }

        do {
            try await export(plan: plan, media: project.media, mediaFolder: folder, to: output) { _ in }
            let pictureTrack = try await tracks(of: output).first { $0.kind == "vide" }
            made.exportTicks = pictureTrack.map { ticks($0.duration) } ?? -1
            made.frames = try await frameCount(of: output)
            let exportFrame = try await frame(of: AVURLAsset(url: output), composition: nil, at: 2700)
            made.exportMagenta = try share(of: magenta, in: exportFrame, photoPlace)
        } catch {
            errors.append("the export: \(error)")
        }

        do {
            try await writeCover(plan: plan, media: project.media, mediaFolder: folder, to: cover)
            let coverPicture = try picture(of: cover)
            made.coverWidth = coverPicture.width
            made.coverHeight = coverPicture.height
        } catch {
            errors.append("the cover: \(error)")
        }

        print("E19: \(name) item \(made.itemTicks) ticks, composition \(made.compositionTicks) ticks, "
            + "export \(made.exportTicks) ticks and \(made.frames) frames, magenta at 4.5 seconds "
            + "\(made.itemMagenta) in the item and \(made.exportMagenta) in the export, "
            + "cover \(made.coverWidth) by \(made.coverHeight), expected \(expected) ticks, "
            + (errors.isEmpty ? "no error" : errors.joined(separator: ", ")))
        return made
    }

    /// Imports the photo and prints the bytes of the file written and the seconds the import took.
    private func imported(_ source: URL, id: String, into folder: URL) async throws -> MediaInfo {
        let began = Date()
        let info = try await importPhoto(from: source, id: MediaID(id), into: folder)
        let seconds = Date().timeIntervalSince(began)
        let written = folder.appendingPathComponent(info.fileName)
        let attributes = try FileManager.default.attributesOfItem(atPath: written.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        print("photo import: \(id) \(info.width) by \(info.height), \(bytes) bytes, \(seconds) seconds")
        return info
    }

    private func assertPhotoFacts(_ info: MediaInfo, id: String, line: UInt = #line) {
        XCTAssertEqual(info.id, MediaID(id), line: line)
        XCTAssertEqual(info.fileName, id + ".mov", line: line)
        XCTAssertEqual(info.kind, .photo, line: line)
        XCTAssertEqual(info.quarterTurns, 0, line: line)
        XCTAssertFalse(info.hasSound, line: line)
        XCTAssertEqual(info.duration, Time(ticks: 108000), line: line)
    }

    /// The movie has the size, one picture track in the coding of at least photoLongest and no sound track. H.264
    /// for a picture its level holds, as a seed's photo in the simulator, HEVC above. Prints its bytes.
    private func assertStillMovie(
        _ movie: URL, width: Int, height: Int, coding: String, line: UInt = #line
    ) async throws {
        let size = try await storedSize(of: movie)
        XCTAssertEqual(size.width, width, line: line)
        XCTAssertEqual(size.height, height, line: line)
        let all = try await tracks(of: movie)
        XCTAssertEqual(all.map { $0.kind }, ["vide"], line: line)
        XCTAssertEqual(all.first?.coding, coding, line: line)
        let length = all.first.map { ticks($0.duration) } ?? -1
        XCTAssertGreaterThanOrEqual(length, 108000, line: line)
        let attributes = try FileManager.default.attributesOfItem(atPath: movie.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        print("photo import: the movie \(movie.lastPathComponent) is \(length) ticks and \(bytes) bytes")
    }

    private func emptyFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("photo-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
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
}

private let photo = TestPhoto.magenta.info
private let magenta = RGB(r: 255, g: 0, b: 255)
private let blue = RGB(r: 0, g: 0, b: 255)
private let red = RGB(r: 255, g: 0, b: 0)
private let black = RGB(r: 0, g: 0, b: 0)
private let green = RGB(r: 0, g: 255, b: 0)

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

/// An uncompressed TIFF stored 400 by 300, red on its left half and green on its right, with the orientation 6
/// (tag 274): turned a quarter clockwise to be upright, so red is at the top of the upright picture.
private func orientedTIFF() -> Data {
    let width = 400
    let height = 300
    var data = Data()
    func short(_ value: Int) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }
    func long(_ value: Int) {
        short(value & 0xFFFF)
        short((value >> 16) & 0xFFFF)
    }
    // Tag, type (3 short, 4 long), count, value. The three bits per sample stand at 146, the pixels at 152.
    let entries: [(Int, Int, Int, Int)] = [
        (256, 3, 1, width), (257, 3, 1, height), (258, 3, 3, 146), (259, 3, 1, 1), (262, 3, 1, 2),
        (273, 4, 1, 152), (274, 3, 1, 6), (277, 3, 1, 3), (278, 3, 1, height), (279, 4, 1, width * height * 3),
        (284, 3, 1, 1),
    ]
    data.append(contentsOf: [0x49, 0x49] as [UInt8])
    short(42)
    long(8)
    short(entries.count)
    for (tag, type, count, value) in entries {
        short(tag)
        short(type)
        long(count)
        if type == 3 && count == 1 {
            short(value)
            short(0)
        } else {
            long(value)
        }
    }
    long(0)
    short(8)
    short(8)
    short(8)
    let left: [UInt8] = [255, 0, 0]
    let right: [UInt8] = [0, 255, 0]
    for _ in 0..<height {
        for x in 0..<width {
            data.append(contentsOf: x < width / 2 ? left : right)
        }
    }
    return data
}

/// The share of the pixels of the rectangle, counted from the top left, within 24 per channel of the colour, or
/// within the number given.
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
private func share(of colour: RGB, in image: CGImage, _ rect: CGRect, within: Int = 24) throws -> Double {
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
            if worst <= within {
                near += 1
            }
            all += 1
        }
    }
    return Double(near) / Double(all)
}
#endif
