import ReelsmithCore
import XCTest

/// A layer is drawn in a frame at time t when timelineStart <= t < timelineStart + duration.
private func holds(_ layer: TextLayer, ticks: Int64) -> Bool {
    let time = Time(ticks: ticks)
    return layer.timelineStart <= time && time < layer.timelineStart + layer.duration
}

final class TextPlanTests: XCTestCase {
    func testAPlanWrittenWithNoTextsHasNone() {
        XCTAssertEqual(RenderPlan(segments: [], duration: .zero).texts, [])
        XCTAssertEqual(RenderPlan(segments: [], duration: .zero, canvas: .landscape).texts, [])
    }

    func testALineWrapsAtEightTenthsOfTheCanvasWidth() {
        XCTAssertEqual(TextGeometry.wrapShare, 0.8)
    }

    func testThePlanOfTheWholeTextSeed() throws {
        let string = "Peace\n" + arabicLine() + "\nbe upon you"

        XCTAssertEqual(try renderPlan(for: Seed.textWide.project).texts, [
            TextLayer(
                text: TextID(1), string: string, timelineStart: .zero, duration: Time(ticks: 4200), x: 960, y: 540,
                rotation: 0, style: .standard, lineWidth: 1536),
        ])
    }

    func testThePlanOfTheBoxedTextSeed() throws {
        var style = TextStyle.standard
        style.size = 96
        style.colour = RGB(r: 255, g: 214, b: 10)
        style.box = true

        XCTAssertEqual(try renderPlan(for: Seed.textBoxWide.project).texts, [
            TextLayer(
                text: TextID(1), string: "BOX", timelineStart: Time(ticks: 600), duration: Time(ticks: 900), x: 960,
                y: 540, rotation: 0, style: style, lineWidth: 1536),
        ])
    }

    func testATextOfAPortraitProjectWrapsAt864() throws {
        var project = Seed.twoClips.project
        project.texts = [textItem(1, "a", .whole)]

        XCTAssertEqual(try renderPlan(for: project).texts.map(\.lineWidth), [864])
    }

    func testThePlanLeavesOutBlankTextsAndTextsWithNoRangeAndKeepsTheOrder() throws {
        var project = projectOfOneClip(ticks: 1200)
        project.texts = [
            textItem(1, " \n ", .whole),
            textItem(2, "past", .range(TextRange(start: Time(ticks: 1200), duration: Time(ticks: 600)))),
            textItem(3, "cut", .range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900)))),
            textItem(4, "whole", .whole),
        ]
        let texts = try renderPlan(for: project).texts

        XCTAssertEqual(texts.map(\.text), [TextID(3), TextID(4)])
        XCTAssertEqual(texts.map(\.timelineStart), [Time(ticks: 600), .zero])
        XCTAssertEqual(texts.map(\.duration), [Time(ticks: 600), Time(ticks: 1200)])
    }

    func testAnEmptyProjectGivesAPlanWithNoText() throws {
        var project = Project()
        project.texts = [textItem(1, "a", .whole)]

        XCTAssertEqual(try renderPlan(for: project).texts, [])
    }

    func testTheBoxedLayerHoldsATimeFromItsStartUpToItsEnd() throws {
        let layer = try XCTUnwrap(try renderPlan(for: Seed.textBoxWide.project).texts.first)

        XCTAssertFalse(holds(layer, ticks: 580))
        XCTAssertTrue(holds(layer, ticks: 600))
        XCTAssertTrue(holds(layer, ticks: 1480))
        XCTAssertFalse(holds(layer, ticks: 1500))
    }
}
