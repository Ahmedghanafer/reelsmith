import '../seeds/test_clip.dart';
import 'time.dart';
import 'words.dart';

class TextID {
  final int raw;

  const TextID(this.raw);

  TextID copyWith({int? raw}) => TextID(raw ?? this.raw);

  @override
  bool operator ==(Object other) => other is TextID && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => 'TextID($raw)';
}

enum TextFont {
  /// Amiri Regular. `allCases` is naskh, naskhBold, system, the order on screen.
  naskh('naskh'),

  /// Amiri Bold.
  naskhBold('naskh-bold'),

  /// The platform's own face.
  system('system');

  final String rawValue;

  const TextFont(this.rawValue);

  static const List<TextFont> allCases = [naskh, naskhBold, system];

  Words get words => switch (this) {
    TextFont.naskh => Words('text.font.naskh'),
    TextFont.naskhBold => Words('text.font.naskhBold'),
    TextFont.system => Words('text.font.system'),
  };

  static const List<String> allWords = ['text.font.naskh', 'text.font.naskhBold', 'text.font.system'];
}

/// A side of the picture, the same in every language.
enum TextAlign {
  left('left'),
  centre('centre'),
  right('right');

  final String rawValue;

  const TextAlign(this.rawValue);

  static const List<TextAlign> allCases = [left, centre, right];
}

class TextStyle {
  final TextFont font;

  /// The font size in canvas pixels.
  final double size;
  final RGB colour;
  final TextAlign align;

  /// Extra space between two lines as a share of size, 0 for none.
  final double lineSpacing;

  /// A line around every letter: black, and white when colour is black.
  final bool outline;

  /// A soft black shadow under the letters.
  final bool shadow;

  /// A black box at 60 percent behind the block.
  final bool box;

  const TextStyle({
    required this.font,
    required this.size,
    required this.colour,
    required this.align,
    required this.lineSpacing,
    required this.outline,
    required this.shadow,
    required this.box,
  });

  static const TextStyle standard = TextStyle(
    font: TextFont.naskh,
    size: 64,
    colour: RGB(r: 255, g: 255, b: 255),
    align: TextAlign.centre,
    lineSpacing: 0,
    outline: false,
    shadow: false,
    box: false,
  );

  static const List<RGB> palette = [
    RGB(r: 255, g: 255, b: 255),
    RGB(r: 0, g: 0, b: 0),
    RGB(r: 255, g: 214, b: 10),
    RGB(r: 255, g: 69, b: 58),
    RGB(r: 48, g: 209, b: 88),
    RGB(r: 10, g: 132, b: 255),
    RGB(r: 255, g: 105, b: 180),
    RGB(r: 142, g: 142, b: 147),
  ];

  TextStyle copyWith({
    TextFont? font,
    double? size,
    RGB? colour,
    TextAlign? align,
    double? lineSpacing,
    bool? outline,
    bool? shadow,
    bool? box,
  }) => TextStyle(
    font: font ?? this.font,
    size: size ?? this.size,
    colour: colour ?? this.colour,
    align: align ?? this.align,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    outline: outline ?? this.outline,
    shadow: shadow ?? this.shadow,
    box: box ?? this.box,
  );

  @override
  bool operator ==(Object other) =>
      other is TextStyle &&
      other.font == font &&
      other.size == size &&
      other.colour == colour &&
      other.align == align &&
      other.lineSpacing == lineSpacing &&
      other.outline == outline &&
      other.shadow == shadow &&
      other.box == box;

  @override
  int get hashCode => Object.hash(font, size, colour, align, lineSpacing, outline, shadow, box);

  @override
  String toString() =>
      'TextStyle(font: $font, size: $size, colour: $colour, align: $align, lineSpacing: $lineSpacing, '
      'outline: $outline, shadow: $shadow, box: $box)';
}

class TextRange {
  /// Timeline time, a whole frame.
  final Time start;

  /// Whole frames.
  final Time duration;

  const TextRange({required this.start, required this.duration});

  TextRange copyWith({Time? start, Time? duration}) =>
      TextRange(start: start ?? this.start, duration: duration ?? this.duration);

  @override
  bool operator ==(Object other) => other is TextRange && other.start == start && other.duration == duration;

  @override
  int get hashCode => Object.hash(start, duration);

  @override
  String toString() => 'TextRange(start: $start, duration: $duration)';
}

/// The Swift enum with the cases whole and range(TextRange).
sealed class TextSpan {
  const TextSpan();

  /// From zero to the end of the project, whatever its length becomes.
  static const TextSpan whole = TextSpanWhole();

  const factory TextSpan.range(TextRange range) = TextSpanRange;
}

final class TextSpanWhole extends TextSpan {
  const TextSpanWhole();

  @override
  bool operator ==(Object other) => other is TextSpanWhole;

  @override
  int get hashCode => (TextSpanWhole).hashCode;

  @override
  String toString() => 'TextSpan.whole';
}

final class TextSpanRange extends TextSpan {
  final TextRange range;

  const TextSpanRange(this.range);

  TextSpanRange copyWith({TextRange? range}) => TextSpanRange(range ?? this.range);

  @override
  bool operator ==(Object other) => other is TextSpanRange && other.range == range;

  @override
  int get hashCode => range.hashCode;

  @override
  String toString() => 'TextSpan.range($range)';
}

class TextItem {
  final TextID id;

  /// As typed. A line break is "\n".
  final String string;
  final TextSpan span;

  /// Canvas pixels: the centre of the block.
  final double x;
  final double y;

  /// Degrees clockwise, above minus 180 and at most 180.
  final double rotation;
  final TextStyle style;

  const TextItem({
    required this.id,
    required this.string,
    required this.span,
    required this.x,
    required this.y,
    required this.rotation,
    required this.style,
  });

  /// The string is empty or holds only spaces and line breaks. The line breaks are those of Swift's
  /// Character.isNewline: U+000A to U+000D, U+0085, U+2028 and U+2029.
  bool get isBlank => string.runes.every(
    (rune) =>
        rune == 0x20 || (rune >= 0x0A && rune <= 0x0D) || rune == 0x85 || rune == 0x2028 || rune == 0x2029,
  );

  TextItem copyWith({
    TextID? id,
    String? string,
    TextSpan? span,
    double? x,
    double? y,
    double? rotation,
    TextStyle? style,
  }) => TextItem(
    id: id ?? this.id,
    string: string ?? this.string,
    span: span ?? this.span,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    style: style ?? this.style,
  );

  @override
  bool operator ==(Object other) =>
      other is TextItem &&
      other.id == id &&
      other.string == string &&
      other.span == span &&
      other.x == x &&
      other.y == y &&
      other.rotation == rotation &&
      other.style == style;

  @override
  int get hashCode => Object.hash(id, string, span, x, y, rotation, style);

  @override
  String toString() =>
      'TextItem(id: $id, string: $string, span: $span, x: $x, y: $y, rotation: $rotation, style: $style)';
}
