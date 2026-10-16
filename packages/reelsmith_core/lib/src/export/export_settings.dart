import '../model/canvas.dart';
import '../model/words.dart';

/// The size of an exported video, by its short side.
enum ExportSize {
  /// `allCases` is hd720, hd1080, uhd4K, the order on screen.
  hd720,
  hd1080,
  uhd4K;

  static const List<ExportSize> allCases = [hd720, hd1080, uhd4K];

  /// Pixels: 720, 1080, 2160.
  int get shortSide => switch (this) {
    ExportSize.hd720 => 720,
    ExportSize.hd1080 => 1080,
    ExportSize.uhd4K => 2160,
  };

  Words get words => switch (this) {
    ExportSize.hd720 => Words('export.size.720'),
    ExportSize.hd1080 => Words('export.size.1080'),
    ExportSize.uhd4K => Words('export.size.4K'),
  };

  /// The keys of `words`, in the order of the cases.
  static const List<String> allWords = ['export.size.720', 'export.size.1080', 'export.size.4K'];

  /// The rates offered at this size.
  List<ExportRate> get rates => switch (this) {
    ExportSize.hd720 || ExportSize.hd1080 => const [ExportRate.thirty, ExportRate.sixty],
    ExportSize.uhd4K => const [ExportRate.thirty, ExportRate.sixty],
  };
}

/// The frames a second of an exported video.
enum ExportRate {
  /// `allCases` is thirty, sixty.
  thirty,
  sixty;

  static const List<ExportRate> allCases = [thirty, sixty];

  /// 30, 60.
  int get framesPerSecond => switch (this) {
    ExportRate.thirty => 30,
    ExportRate.sixty => 60,
  };

  Words get words => switch (this) {
    ExportRate.thirty => Words('export.rate.30'),
    ExportRate.sixty => Words('export.rate.60'),
  };

  /// The keys of `words`, in the order of the cases.
  static const List<String> allWords = ['export.rate.30', 'export.rate.60'];
}

/// The size and the rate of one export.
class ExportSettings {
  final ExportSize size;
  final ExportRate rate;

  const ExportSettings({required this.size, required this.rate});

  /// hd1080 at thirty: every export before the choice existed, and every preview.
  static const ExportSettings standard = ExportSettings(size: ExportSize.hd1080, rate: ExportRate.thirty);

  /// What the export button holds when the editor opens: standard.
  static const ExportSettings startChoice = standard;

  /// The Swift width(on:). Pixels: the canvas width times the short side of the size, divided by 1080.
  int width(Canvas canvas) => canvas.width * size.shortSide ~/ 1080;

  /// The Swift height(on:). Pixels: the canvas height times the short side of the size, divided by 1080.
  int height(Canvas canvas) => canvas.height * size.shortSide ~/ 1080;

  /// The Swift choosing(_: ExportSize). That size, with the rate kept when the size offers it, else thirty.
  ExportSettings choosingSize(ExportSize size) =>
      ExportSettings(size: size, rate: size.rates.contains(rate) ? rate : ExportRate.thirty);

  /// The Swift choosing(_: ExportRate). That rate when the size offers it, else these settings unchanged.
  ExportSettings choosingRate(ExportRate rate) =>
      size.rates.contains(rate) ? ExportSettings(size: size, rate: rate) : this;

  ExportSettings copyWith({ExportSize? size, ExportRate? rate}) =>
      ExportSettings(size: size ?? this.size, rate: rate ?? this.rate);

  @override
  bool operator ==(Object other) => other is ExportSettings && other.size == size && other.rate == rate;

  @override
  int get hashCode => Object.hash(size, rate);

  @override
  String toString() => 'ExportSettings(size: $size, rate: $rate)';
}
