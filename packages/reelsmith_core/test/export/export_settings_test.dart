import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testTheThreeSizesAndTheTwoRatesInTheirOrder', () {
    expect(ExportSize.allCases, [ExportSize.hd720, ExportSize.hd1080, ExportSize.uhd4K]);
    expect(ExportSize.allCases.map((size) => size.shortSide).toList(), [720, 1080, 2160]);
    expect(ExportRate.allCases, [ExportRate.thirty, ExportRate.sixty]);
    expect(ExportRate.allCases.map((rate) => rate.framesPerSecond).toList(), [30, 60]);
  });

  test('testTheWordsOfEachSizeAndRateAndAllWordsInTheOrderOfTheCases', () {
    expect(ExportSize.hd720.words, Words('export.size.720'));
    expect(ExportSize.hd1080.words, Words('export.size.1080'));
    expect(ExportSize.uhd4K.words, Words('export.size.4K'));
    expect(ExportSize.allWords, ['export.size.720', 'export.size.1080', 'export.size.4K']);
    expect(ExportSize.allWords, ExportSize.allCases.map((size) => size.words.key).toList());

    expect(ExportRate.thirty.words, Words('export.rate.30'));
    expect(ExportRate.sixty.words, Words('export.rate.60'));
    expect(ExportRate.allWords, ['export.rate.30', 'export.rate.60']);
    expect(ExportRate.allWords, ExportRate.allCases.map((rate) => rate.words.key).toList());
  });

  test('testTheStandardAndTheStartChoiceAre1080At30', () {
    expect(ExportSettings.standard, const ExportSettings(size: ExportSize.hd1080, rate: ExportRate.thirty));
    expect(ExportSettings.startChoice, const ExportSettings(size: ExportSize.hd1080, rate: ExportRate.thirty));
  });

  test('testTheSixSizesOnTheTwoCanvases', () {
    final wanted = <(ExportSize, Canvas, int, int)>[
      (ExportSize.hd720, Canvas.landscape, 1280, 720),
      (ExportSize.hd1080, Canvas.landscape, 1920, 1080),
      (ExportSize.uhd4K, Canvas.landscape, 3840, 2160),
      (ExportSize.hd720, Canvas.portrait, 720, 1280),
      (ExportSize.hd1080, Canvas.portrait, 1080, 1920),
      (ExportSize.uhd4K, Canvas.portrait, 2160, 3840),
    ];
    for (final (size, canvas, width, height) in wanted) {
      for (final rate in ExportRate.allCases) {
        final settings = ExportSettings(size: size, rate: rate);
        expect(settings.width(canvas), width, reason: '$size $rate $canvas');
        expect(settings.height(canvas), height, reason: '$size $rate $canvas');
      }
    }
  });

  // Branch 1: every size offers both rates.
  test('testEverySizeOffersBothRatesAndAChoiceKeepsTheOther', () {
    for (final size in ExportSize.allCases) {
      expect(size.rates, [ExportRate.thirty, ExportRate.sixty], reason: '$size');
    }
    const sixty = ExportSettings(size: ExportSize.hd1080, rate: ExportRate.sixty);

    expect(sixty.choosingSize(ExportSize.hd720), const ExportSettings(size: ExportSize.hd720, rate: ExportRate.sixty));
    expect(sixty.choosingSize(ExportSize.uhd4K), const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty));
    expect(
      const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.thirty).choosingRate(ExportRate.sixty),
      const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty),
    );
    expect(ExportSettings.standard.choosingRate(ExportRate.sixty), sixty);
  });
}
