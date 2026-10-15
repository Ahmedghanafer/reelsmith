import '../model/media.dart';
import '../model/time.dart';

class RGB {
  final int r;
  final int g;
  final int b;

  const RGB({required this.r, required this.g, required this.b});

  RGB copyWith({int? r, int? g, int? b}) => RGB(r: r ?? this.r, g: g ?? this.g, b: b ?? this.b);

  @override
  bool operator ==(Object other) => other is RGB && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'RGB(r: $r, g: $g, b: $b)';
}

class TestClip {
  final String name;
  final int storedWidth;
  final int storedHeight;
  final Time duration;
  final int framesPerSecond;
  final int quarterTurns;
  final bool hasSound;

  /// The colour of the left half of the stored picture.
  final RGB left;

  /// The colour of the right half.
  final RGB right;

  const TestClip({
    required this.name,
    required this.storedWidth,
    required this.storedHeight,
    required this.duration,
    required this.framesPerSecond,
    required this.quarterTurns,
    required this.hasSound,
    required this.left,
    required this.right,
  });

  /// The id is MediaID(name), the file name is name + ".mov".
  MediaInfo get info => MediaInfo(
    id: MediaID(name),
    fileName: '$name.mov',
    width: storedWidth,
    height: storedHeight,
    duration: duration,
    quarterTurns: quarterTurns,
    hasSound: hasSound,
  );

  static const TestClip blue = TestClip(
    name: 'blue',
    storedWidth: 1920,
    storedHeight: 1080,
    duration: Time(ticks: 1800),
    framesPerSecond: 30,
    quarterTurns: 0,
    hasSound: true,
    left: RGB(r: 0, g: 0, b: 255),
    right: RGB(r: 0, g: 0, b: 255),
  );

  static const TestClip red = TestClip(
    name: 'red',
    storedWidth: 1080,
    storedHeight: 1920,
    duration: Time(ticks: 2400),
    framesPerSecond: 30,
    quarterTurns: 0,
    hasSound: true,
    left: RGB(r: 255, g: 0, b: 0),
    right: RGB(r: 255, g: 0, b: 0),
  );

  static const TestClip green = TestClip(
    name: 'green',
    storedWidth: 1080,
    storedHeight: 1920,
    duration: Time(ticks: 1200),
    framesPerSecond: 30,
    quarterTurns: 0,
    hasSound: false,
    left: RGB(r: 0, g: 255, b: 0),
    right: RGB(r: 0, g: 255, b: 0),
  );

  static const TestClip turned = TestClip(
    name: 'turned',
    storedWidth: 1920,
    storedHeight: 1080,
    duration: Time(ticks: 1200),
    framesPerSecond: 30,
    quarterTurns: 1,
    hasSound: false,
    left: RGB(r: 255, g: 255, b: 255),
    right: RGB(r: 0, g: 0, b: 255),
  );

  static const TestClip fast = TestClip(
    name: 'fast',
    storedWidth: 1080,
    storedHeight: 1920,
    duration: Time(ticks: 1200),
    framesPerSecond: 60,
    quarterTurns: 0,
    hasSound: false,
    left: RGB(r: 255, g: 255, b: 0),
    right: RGB(r: 255, g: 255, b: 0),
  );

  static const List<TestClip> all = [blue, red, green, turned, fast];

  TestClip copyWith({
    String? name,
    int? storedWidth,
    int? storedHeight,
    Time? duration,
    int? framesPerSecond,
    int? quarterTurns,
    bool? hasSound,
    RGB? left,
    RGB? right,
  }) => TestClip(
    name: name ?? this.name,
    storedWidth: storedWidth ?? this.storedWidth,
    storedHeight: storedHeight ?? this.storedHeight,
    duration: duration ?? this.duration,
    framesPerSecond: framesPerSecond ?? this.framesPerSecond,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    hasSound: hasSound ?? this.hasSound,
    left: left ?? this.left,
    right: right ?? this.right,
  );

  @override
  bool operator ==(Object other) =>
      other is TestClip &&
      other.name == name &&
      other.storedWidth == storedWidth &&
      other.storedHeight == storedHeight &&
      other.duration == duration &&
      other.framesPerSecond == framesPerSecond &&
      other.quarterTurns == quarterTurns &&
      other.hasSound == hasSound &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode =>
      Object.hash(name, storedWidth, storedHeight, duration, framesPerSecond, quarterTurns, hasSound, left, right);

  @override
  String toString() => 'TestClip($name)';
}
