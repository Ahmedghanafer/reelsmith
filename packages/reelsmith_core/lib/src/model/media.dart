import 'time.dart';

class MediaID {
  /// A seed clip uses its name, a picked video a new UUID string.
  final String raw;

  const MediaID(this.raw);

  MediaID copyWith({String? raw}) => MediaID(raw ?? this.raw);

  @override
  bool operator ==(Object other) => other is MediaID && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => 'MediaID($raw)';
}

enum MediaKind {
  video('video'),
  photo('photo');

  final String rawValue;

  const MediaKind(this.rawValue);
}

class MediaInfo {
  final MediaID id;

  /// The file's name inside the media folder, with its extension.
  final String fileName;

  /// Pixels as stored, before any turn.
  final int width;
  final int height;

  /// The length of the picture track, rounded down to a tick. photoLongest for a photo.
  final Time duration;

  /// 0 to 3: clockwise quarter turns to apply to the stored picture to show it upright.
  final int quarterTurns;
  final bool hasSound;

  /// .video when a stored file lacks it.
  final MediaKind kind;

  const MediaInfo({
    required this.id,
    required this.fileName,
    required this.width,
    required this.height,
    required this.duration,
    required this.quarterTurns,
    required this.hasSound,
    this.kind = MediaKind.video,
  });

  /// 1800 ticks: a photo clip when it is added.
  static const Time photoLength = Time(ticks: 1800);

  /// 108000 ticks: the media duration of every photo.
  static const Time photoLongest = Time(ticks: 108000);

  MediaInfo copyWith({
    MediaID? id,
    String? fileName,
    int? width,
    int? height,
    Time? duration,
    int? quarterTurns,
    bool? hasSound,
    MediaKind? kind,
  }) => MediaInfo(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    width: width ?? this.width,
    height: height ?? this.height,
    duration: duration ?? this.duration,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    hasSound: hasSound ?? this.hasSound,
    kind: kind ?? this.kind,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaInfo &&
      other.id == id &&
      other.fileName == fileName &&
      other.width == width &&
      other.height == height &&
      other.duration == duration &&
      other.quarterTurns == quarterTurns &&
      other.hasSound == hasSound &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, fileName, width, height, duration, quarterTurns, hasSound, kind);

  @override
  String toString() =>
      'MediaInfo(id: $id, fileName: $fileName, width: $width, height: $height, duration: $duration, '
      'quarterTurns: $quarterTurns, hasSound: $hasSound, kind: $kind)';
}
