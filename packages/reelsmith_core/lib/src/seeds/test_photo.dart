import '../model/media.dart';
import 'test_clip.dart';

/// The values of a test photo. Its picture and still movie are written by the Swift writers.
class TestPhoto {
  /// The picture is name + ".png", its still movie name + ".mov".
  final String name;

  /// Upright pixels.
  final int width;
  final int height;

  /// The colour of the whole picture.
  final RGB colour;

  const TestPhoto({required this.name, required this.width, required this.height, required this.colour});

  /// The id is MediaID(name), the file name is name + ".mov", the still movie of the picture: a photo of
  /// photoLongest with no turn and no sound.
  MediaInfo get info => MediaInfo(
    id: MediaID(name),
    fileName: '$name.mov',
    width: width,
    height: height,
    duration: MediaInfo.photoLongest,
    quarterTurns: 0,
    hasSound: false,
    kind: MediaKind.photo,
  );

  static const TestPhoto magenta = TestPhoto(
    name: 'magenta',
    width: 1080,
    height: 1440,
    colour: RGB(r: 255, g: 0, b: 255),
  );

  TestPhoto copyWith({String? name, int? width, int? height, RGB? colour}) => TestPhoto(
    name: name ?? this.name,
    width: width ?? this.width,
    height: height ?? this.height,
    colour: colour ?? this.colour,
  );

  @override
  bool operator ==(Object other) =>
      other is TestPhoto &&
      other.name == name &&
      other.width == width &&
      other.height == height &&
      other.colour == colour;

  @override
  int get hashCode => Object.hash(name, width, height, colour);
}
