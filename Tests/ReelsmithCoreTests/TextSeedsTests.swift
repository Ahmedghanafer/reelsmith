import ReelsmithCore
import XCTest

final class TextSeedsTests: XCTestCase {
    func testTheTwoTextSeedsAreReadFromTheirNames() {
        XCTAssertEqual(Seed(rawValue: "text-wide"), .textWide)
        XCTAssertEqual(Seed(rawValue: "text-box-wide"), .textBoxWide)
        XCTAssertEqual(LaunchOptions(arguments: ["-seed", "text-wide"]).seed, .textWide)
        XCTAssertEqual(LaunchOptions(arguments: ["-seed", "text-box-wide"]).seed, .textBoxWide)
    }

    func testATextSeedHasTheClipsOfTheWideSeedAndOneText() {
        for seed in [Seed.textWide, Seed.textBoxWide] {
            let project = seed.project

            XCTAssertEqual(seed.testClips, [.blue, .red])
            XCTAssertEqual(project.canvas, .landscape)
            XCTAssertEqual(project.clips, Seed.twoClipsWide.project.clips)
            XCTAssertEqual(project.media, Seed.twoClipsWide.project.media)
            XCTAssertEqual(project.clips.map(\.id), [ClipID(1), ClipID(2)])
            XCTAssertEqual(project.clips.map(\.media), [MediaID("blue"), MediaID("red")])
            XCTAssertEqual(project.nextClipID, 3)
            XCTAssertEqual(project.duration, Time(ticks: 4200))
            XCTAssertEqual(project.texts.map(\.id), [TextID(1)])
            XCTAssertEqual(project.nextTextID, 2)
        }
    }

    func testTheOtherFourSeedsHaveNoText() {
        for seed in [Seed.empty, Seed.twoClips, Seed.threeClips, Seed.twoClipsWide] {
            XCTAssertEqual(seed.project.texts, [])
            XCTAssertEqual(seed.project.nextTextID, 1)
            XCTAssertNil(seed.selectedText)
        }
    }

    func testATextSeedStartsWithItsTextSelected() {
        XCTAssertEqual(Seed.textWide.selectedText, TextID(1))
        XCTAssertEqual(Seed.textBoxWide.selectedText, TextID(1))
    }

    func testTheWholeTextSeedHoldsThreeLinesWithTheArabicLineBetween() throws {
        let text = try XCTUnwrap(Seed.textWide.project.texts.first)
        let lines = text.string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines.first, "Peace")
        XCTAssertEqual(lines.last, "be upon you")
        XCTAssertEqual(arabicLineScalars.count, 21)
        XCTAssertEqual(lines.dropFirst().first?.unicodeScalars.map(\.value), arabicLineScalars)
        XCTAssertEqual(text.span, .whole)
        XCTAssertEqual(text.x, 960)
        XCTAssertEqual(text.y, 540)
        XCTAssertEqual(text.rotation, 0)
        XCTAssertEqual(text.style, .standard)
        XCTAssertEqual(text.style.size, 64)
    }

    func testTheBoxedTextSeedHoldsOneYellowBoxedWordForAPartOfTheFirstClip() {
        var style = TextStyle.standard
        style.size = 96
        style.colour = RGB(r: 255, g: 214, b: 10)
        style.box = true

        XCTAssertEqual(Seed.textBoxWide.project.texts, [
            TextItem(
                id: TextID(1), string: "BOX",
                span: .range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900))), x: 960, y: 540,
                rotation: 0, style: style),
        ])
    }
}
