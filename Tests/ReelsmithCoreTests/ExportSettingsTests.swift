import ReelsmithCore
import XCTest

final class ExportSettingsTests: XCTestCase {
    func testTheThreeSizesAndTheTwoRatesInTheirOrder() {
        XCTAssertEqual(ExportSize.allCases, [.hd720, .hd1080, .uhd4K])
        XCTAssertEqual(ExportSize.allCases.map(\.shortSide), [720, 1080, 2160])
        XCTAssertEqual(ExportRate.allCases, [.thirty, .sixty])
        XCTAssertEqual(ExportRate.allCases.map(\.framesPerSecond), [30, 60])
    }

    func testTheWordsOfEachSizeAndRateAndAllWordsInTheOrderOfTheCases() {
        XCTAssertEqual(ExportSize.hd720.words, Words("export.size.720"))
        XCTAssertEqual(ExportSize.hd1080.words, Words("export.size.1080"))
        XCTAssertEqual(ExportSize.uhd4K.words, Words("export.size.4K"))
        XCTAssertEqual(ExportSize.allWords, ["export.size.720", "export.size.1080", "export.size.4K"])
        XCTAssertEqual(ExportSize.allWords, ExportSize.allCases.map(\.words.key))

        XCTAssertEqual(ExportRate.thirty.words, Words("export.rate.30"))
        XCTAssertEqual(ExportRate.sixty.words, Words("export.rate.60"))
        XCTAssertEqual(ExportRate.allWords, ["export.rate.30", "export.rate.60"])
        XCTAssertEqual(ExportRate.allWords, ExportRate.allCases.map(\.words.key))
    }

    func testTheStandardAndTheStartChoiceAre1080At30() {
        XCTAssertEqual(ExportSettings.standard, ExportSettings(size: .hd1080, rate: .thirty))
        XCTAssertEqual(ExportSettings.startChoice, ExportSettings(size: .hd1080, rate: .thirty))
    }

    func testTheSixSizesOnTheTwoCanvases() {
        let wanted: [(ExportSize, Canvas, Int, Int)] = [
            (.hd720, .landscape, 1280, 720), (.hd1080, .landscape, 1920, 1080), (.uhd4K, .landscape, 3840, 2160),
            (.hd720, .portrait, 720, 1280), (.hd1080, .portrait, 1080, 1920), (.uhd4K, .portrait, 2160, 3840),
        ]
        for (size, canvas, width, height) in wanted {
            for rate in ExportRate.allCases {
                let settings = ExportSettings(size: size, rate: rate)
                XCTAssertEqual(settings.width(on: canvas), width, "\(size) \(rate) \(canvas)")
                XCTAssertEqual(settings.height(on: canvas), height, "\(size) \(rate) \(canvas)")
            }
        }
    }

    /// Branch 1: every size offers both rates.
    func testEverySizeOffersBothRatesAndAChoiceKeepsTheOther() {
        for size in ExportSize.allCases {
            XCTAssertEqual(size.rates, [.thirty, .sixty], "\(size)")
        }
        let sixty = ExportSettings(size: .hd1080, rate: .sixty)

        XCTAssertEqual(sixty.choosing(ExportSize.hd720), ExportSettings(size: .hd720, rate: .sixty))
        XCTAssertEqual(sixty.choosing(ExportSize.uhd4K), ExportSettings(size: .uhd4K, rate: .sixty))
        XCTAssertEqual(
            ExportSettings(size: .uhd4K, rate: .thirty).choosing(ExportRate.sixty),
            ExportSettings(size: .uhd4K, rate: .sixty))
        XCTAssertEqual(ExportSettings.standard.choosing(ExportRate.sixty), sixty)
    }
}
