#if canImport(CoreText)
import CoreGraphics
import CoreImage
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The cover of a draft, written by `writeCover` from the plan of a seed and read back with Core Image. The clips
/// and the covers go into the folder of `ExportTests`. A place is counted from the top left of the cover. A colour
/// matches within 24 of 255 per channel.
final class CoverTests: XCTestCase {
    struct Read {
        var width: Int
        var height: Int
        var middle: RGB
    }

    struct Covered {
        var file: URL
        var first: Double
        var second: Double
        /// The cover after the first call.
        var before: Read
        var secondBegan: Date
    }

    /// The first two covers of the process, both of the plan of two-clips-wide into one file. Every test of the
    /// class waits for it before its own cover, so these two are the first.
    static let twoClipsWide = Task<Covered, Error> {
        let seed = Seed.twoClipsWide
        try await writeClips(of: seed)
        let plan = try renderPlan(for: seed.project)
        let file = ExportTests.folder.appendingPathComponent("two-clips-wide.cover.jpg")
        let began = Date()
        try await writeCover(plan: plan, media: seed.project.media, mediaFolder: ExportTests.folder, to: file)
        let first = Date().timeIntervalSince(began)
        let before = try read(file)
        let secondBegan = Date()
        try await writeCover(plan: plan, media: seed.project.media, mediaFolder: ExportTests.folder, to: file)
        let second = Date().timeIntervalSince(secondBegan)
        return Covered(file: file, first: first, second: second, before: before, secondBegan: secondBegan)
    }

    func testTheCoverOfTwoClipsWideIs360WideAnd202Or203HighWithABlueMiddle() async throws {
        let cover = try read(try await Self.twoClipsWide.value.file)
        XCTAssertEqual(cover.width, 360)
        XCTAssertTrue([202, 203].contains(cover.height), "the cover is \(cover.height) high")
        XCTAssertLessThanOrEqual(worst(cover.middle, blue), 24, "the middle reads \(cover.middle)")
    }

    func testTheCoverOfTwoClipsIs202Or203By360BlueInTheMiddleAndBlack10RowsFromTheTop() async throws {
        _ = try await Self.twoClipsWide.value
        let file = try await cover(of: Seed.twoClips.project, name: "two-clips.cover.jpg")
        let cover = try read(file)
        XCTAssertTrue([202, 203].contains(cover.width), "the cover is \(cover.width) wide")
        XCTAssertEqual(cover.height, 360)
        XCTAssertLessThanOrEqual(worst(cover.middle, blue), 24, "the middle reads \(cover.middle)")
        let top = try colour(in: file, x: cover.width / 2, y: 10)
        XCTAssertLessThanOrEqual(worst(top, RGB(r: 0, g: 0, b: 0)), 24, "10 rows from the top reads \(top)")
    }

    /// The box is black at 60 percent and its letters are yellow, drawn over blue by the compositor.
    func testTheCoverOfTextBoxWideWithItsTextForTheWholeVideoIsNotBlueInTheMiddle() async throws {
        _ = try await Self.twoClipsWide.value
        var project = Seed.textBoxWide.project
        project.texts[0].span = .whole
        let cover = try read(try await cover(of: project, name: "text-box-wide.cover.jpg"))
        XCTAssertGreaterThan(worst(cover.middle, blue), 24, "the middle reads \(cover.middle)")
    }

    func testASecondCoverToTheSameFileReplacesItAndIsReadAsBefore() async throws {
        let covered = try await Self.twoClipsWide.value
        let changed = try XCTUnwrap(URL(fileURLWithPath: covered.file.path)
            .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        XCTAssertGreaterThanOrEqual(changed, covered.secondBegan, "the second call did not replace the file")
        let after = try read(covered.file)
        XCTAssertEqual(after.width, covered.before.width)
        XCTAssertEqual(after.height, covered.before.height)
        XCTAssertLessThanOrEqual(worst(after.middle, covered.before.middle), 24, "the middle reads \(after.middle)")
    }

    func testThePlanOfEmptyThrowsNothingToExportAndWritesNoFile() async throws {
        _ = try await Self.twoClipsWide.value
        let file = ExportTests.folder.appendingPathComponent("empty.cover.jpg")
        let project = Seed.empty.project
        await assertThrows(.nothingToExport, file: file) {
            try await writeCover(
                plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder, to: file)
        }
    }

    func testAPlanWhoseMediaFileIsNotInTheFolderThrowsSourceMissingAndWritesNoFile() async throws {
        _ = try await Self.twoClipsWide.value
        let file = ExportTests.folder.appendingPathComponent("missing-media.cover.jpg")
        let noMedia = ExportTests.folder.appendingPathComponent("cover-no-media")
        try FileManager.default.createDirectory(at: noMedia, withIntermediateDirectories: true)
        let project = Seed.twoClipsWide.project
        await assertThrows(.sourceMissing(TestClip.blue.info.id), file: file) {
            try await writeCover(plan: renderPlan(for: project), media: project.media, mediaFolder: noMedia, to: file)
        }
    }

    func testAFileInsideAFolderThatIsNotThereThrowsCannotWriteAndWritesNoFile() async throws {
        _ = try await Self.twoClipsWide.value
        let file = ExportTests.folder.appendingPathComponent("not-there").appendingPathComponent("cover.jpg")
        let project = Seed.twoClipsWide.project
        await assertThrows(.cannotWrite, file: file) {
            try await writeCover(
                plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder, to: file)
        }
    }

    /// E16: the seconds are printed, and a limit holds only above 30.
    func testTheFirstAndTheSecondCoverOfTwoClipsWideTakeAtMost30SecondsEach() async throws {
        let covered = try await Self.twoClipsWide.value
        print("cover: two-clips-wide, the first cover of the process took \(covered.first) seconds, "
            + "the second \(covered.second) seconds")
        XCTAssertLessThanOrEqual(covered.first, 30)
        XCTAssertLessThanOrEqual(covered.second, 30)
    }

    /// Writes the cover of the plan of a project into the folder of `ExportTests` and returns the file.
    private func cover(of project: Project, name: String) async throws -> URL {
        let file = ExportTests.folder.appendingPathComponent(name)
        try await writeCover(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder, to: file)
        return file
    }

    private func assertThrows(
        _ wanted: EngineError, file: URL, line: UInt = #line, _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("no error, \(wanted) wanted", line: line)
        } catch {
            XCTAssertEqual(error as? EngineError, wanted, line: line)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "a file was written", line: line)
    }
}

private let blue = RGB(r: 0, g: 0, b: 255)

private func writeClips(of seed: Seed) async throws {
    for clip in seed.testClips {
        _ = try await writeTestClip(clip, to: ExportTests.folder)
    }
}

/// https://developer.apple.com/documentation/coreimage/ciimage/init(contentsof:)
private func read(_ file: URL) throws -> CoverTests.Read {
    let image = try XCTUnwrap(CIImage(contentsOf: file), "Core Image cannot read \(file.lastPathComponent)")
    let width = Int(image.extent.width)
    let height = Int(image.extent.height)
    return CoverTests.Read(width: width, height: height, middle: try colour(in: file, x: width / 2, y: height / 2))
}

/// One pixel of the file, read with Core Image, which counts from the bottom left.
/// https://developer.apple.com/documentation/coreimage/cicontext/render(_:tobitmap:rowbytes:bounds:format:colorspace:)
private func colour(in file: URL, x: Int, y: Int) throws -> RGB {
    let image = try XCTUnwrap(CIImage(contentsOf: file), "Core Image cannot read \(file.lastPathComponent)")
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    var bytes = [UInt8](repeating: 0, count: 4)
    let row = Int(image.extent.height) - 1 - y
    CIContext().render(
        image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: x, y: row, width: 1, height: 1), format: .RGBA8,
        colorSpace: space)
    return RGB(r: bytes[0], g: bytes[1], b: bytes[2])
}

/// The largest difference of the three channels.
private func worst(_ colour: RGB, _ wanted: RGB) -> Int {
    [abs(Int(colour.r) - Int(wanted.r)), abs(Int(colour.g) - Int(wanted.g)), abs(Int(colour.b) - Int(wanted.b))]
        .max() ?? 0
}
#endif
