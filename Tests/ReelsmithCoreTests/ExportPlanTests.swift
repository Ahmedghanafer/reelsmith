import ReelsmithCore
import XCTest

/// A stored number at a short side: times the short side, then divided by 1080.
private func scaled(_ value: Double, _ shortSide: Int) -> Double {
    value * Double(shortSide) / 1080
}

private let everySetting: [ExportSettings] = ExportSize.allCases.flatMap { size in
    ExportRate.allCases.map { ExportSettings(size: size, rate: $0) }
}

final class ExportPlanTests: XCTestCase {
    func testThePlanOfEverySeedIsThePlanAtStandard() throws {
        for seed in Seed.allCases {
            let plan = try renderPlan(for: seed.project)

            XCTAssertEqual(plan, try renderPlan(for: seed.project, settings: .standard), seed.rawValue)
            XCTAssertEqual(plan.settings, .standard, seed.rawValue)
            XCTAssertEqual(plan.width, seed.canvas.width, seed.rawValue)
            XCTAssertEqual(plan.height, seed.canvas.height, seed.rawValue)
            XCTAssertEqual(plan.framesPerSecond, 30, seed.rawValue)
        }
        XCTAssertEqual(RenderPlan(segments: [], duration: .zero).settings, .standard)
    }

    func testTheWideSeedIsFittedInto720AndInto4K() throws {
        let small = try renderPlan(for: Seed.twoClipsWide.project, settings: ExportSettings(size: .hd720, rate: .thirty))
        XCTAssertEqual(small.width, 1280)
        XCTAssertEqual(small.height, 720)
        XCTAssertEqual(small.segments.map(\.placement), [
            Placement(quarterTurns: 0, x: 0, y: 0, width: 1280, height: 720),
            Placement(quarterTurns: 0, x: 437.5, y: 0, width: 405, height: 720),
        ])

        let large = try renderPlan(for: Seed.twoClipsWide.project, settings: ExportSettings(size: .uhd4K, rate: .thirty))
        XCTAssertEqual(large.width, 3840)
        XCTAssertEqual(large.height, 2160)
        XCTAssertEqual(large.segments.map(\.placement), [
            Placement(quarterTurns: 0, x: 0, y: 0, width: 3840, height: 2160),
            Placement(quarterTurns: 0, x: 1312.5, y: 0, width: 1215, height: 2160),
        ])
    }

    func testTheBoxedTextIsScaledTo4KAndTo720() throws {
        let stored = try XCTUnwrap(Seed.textBoxWide.project.texts.first)

        let large = try renderPlan(for: Seed.textBoxWide.project, settings: ExportSettings(size: .uhd4K, rate: .thirty))
        let big = try XCTUnwrap(large.texts.first)
        XCTAssertEqual(big.x, stored.x * 2)
        XCTAssertEqual(big.y, stored.y * 2)
        XCTAssertEqual(big.style.size, 192)
        XCTAssertEqual(big.lineWidth, 3072)

        let small = try renderPlan(for: Seed.textBoxWide.project, settings: ExportSettings(size: .hd720, rate: .sixty))
        let little = try XCTUnwrap(small.texts.first)
        XCTAssertEqual(little.x, scaled(stored.x, 720))
        XCTAssertEqual(little.y, scaled(stored.y, 720))
        XCTAssertEqual(little.style.size, scaled(stored.style.size, 720))
        XCTAssertEqual(little.lineWidth, 1024)
        XCTAssertEqual(small.framesPerSecond, 60)
    }

    func testEverySizeAndRateKeepsTheTimesTheSoundAndTheLookOfTheStandardPlan() throws {
        for seed in [Seed.twoClipsWide, Seed.textBoxWide, Seed.musicWide] {
            let standard = try renderPlan(for: seed.project)
            for settings in everySetting {
                let plan = try renderPlan(for: seed.project, settings: settings)
                let name = seed.rawValue + " \(settings.size) \(settings.rate)"

                XCTAssertEqual(plan.segments.count, standard.segments.count, name)
                for (segment, before) in zip(plan.segments, standard.segments) {
                    XCTAssertEqual(segment.clip, before.clip, name)
                    XCTAssertEqual(segment.media, before.media, name)
                    XCTAssertEqual(segment.sourceStart, before.sourceStart, name)
                    XCTAssertEqual(segment.timelineStart, before.timelineStart, name)
                    XCTAssertEqual(segment.duration, before.duration, name)
                    XCTAssertEqual(segment.placement.quarterTurns, before.placement.quarterTurns, name)
                    XCTAssertEqual(segment.hasSound, before.hasSound, name)
                }
                XCTAssertEqual(plan.duration, standard.duration, name)
                XCTAssertEqual(plan.canvas, standard.canvas, name)
                XCTAssertEqual(plan.sound, standard.sound, name)

                XCTAssertEqual(plan.texts.count, standard.texts.count, name)
                for (text, before) in zip(plan.texts, standard.texts) {
                    XCTAssertEqual(text.text, before.text, name)
                    XCTAssertEqual(text.string, before.string, name)
                    XCTAssertEqual(text.timelineStart, before.timelineStart, name)
                    XCTAssertEqual(text.duration, before.duration, name)
                    XCTAssertEqual(text.rotation, before.rotation, name)
                    XCTAssertEqual(text.style.font, before.style.font, name)
                    XCTAssertEqual(text.style.colour, before.style.colour, name)
                    XCTAssertEqual(text.style.align, before.style.align, name)
                    XCTAssertEqual(text.style.lineSpacing, before.style.lineSpacing, name)
                    XCTAssertEqual(text.style.outline, before.style.outline, name)
                    XCTAssertEqual(text.style.shadow, before.style.shadow, name)
                    XCTAssertEqual(text.style.box, before.style.box, name)
                }
            }
        }
    }

    func testAPortraitSeedAt4KAndTheEmptyProjectAt720() throws {
        let large = try renderPlan(for: Seed.twoClips.project, settings: ExportSettings(size: .uhd4K, rate: .thirty))
        XCTAssertEqual(large.width, 2160)
        XCTAssertEqual(large.height, 3840)

        let small = ExportSettings(size: .hd720, rate: .thirty)
        XCTAssertEqual(
            try renderPlan(for: Seed.empty.project, settings: small),
            RenderPlan(segments: [], duration: .zero, settings: small))
    }

    func testAtTheStandardSizeTheNumbersOfATextAreCopiedNotScaled() throws {
        var project = Seed.twoClipsWide.project
        project.texts = [
            TextItem(id: TextID(1), string: "a", span: .whole, x: 3.857142857142857, y: 540, rotation: 0, style: .standard),
        ]

        XCTAssertEqual(try renderPlan(for: project, settings: .standard).texts.map(\.x), [3.857142857142857])
    }
}
