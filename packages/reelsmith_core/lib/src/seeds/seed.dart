import '../model/canvas.dart';
import '../model/media.dart';
import '../model/project.dart';
import '../model/sound.dart';
import '../model/text.dart';
import '../model/time.dart';
import 'test_clip.dart';
import 'test_photo.dart';
import 'test_tone.dart';

enum Seed {
  empty('empty'),
  twoClips('two-clips'),
  threeClips('three-clips'),
  twoClipsWide('two-clips-wide'),

  /// Three lines for the whole video.
  textWide('text-wide'),

  /// One boxed word for a part of the first clip.
  textBoxWide('text-box-wide'),

  /// The clips of two-clips-wide under the long test tone.
  musicWide('music-wide'),

  /// Blue, the magenta photo for 1800 ticks, then red, on the landscape canvas.
  photoWide('photo-wide');

  final String rawValue;

  const Seed(this.rawValue);

  static const List<Seed> allCases = [
    empty,
    twoClips,
    threeClips,
    twoClipsWide,
    textWide,
    textBoxWide,
    musicWide,
    photoWide,
  ];

  /// The Swift init(rawValue:): null for an unknown name.
  static Seed? fromRawValue(String rawValue) {
    for (final seed in allCases) {
      if (seed.rawValue == rawValue) {
        return seed;
      }
    }
    return null;
  }

  Canvas get canvas => switch (this) {
    Seed.empty || Seed.twoClips || Seed.threeClips => Canvas.portrait,
    Seed.twoClipsWide || Seed.textWide || Seed.textBoxWide || Seed.musicWide || Seed.photoWide => Canvas.landscape,
  };

  List<TestClip> get testClips => switch (this) {
    Seed.empty => const [],
    Seed.twoClips ||
    Seed.twoClipsWide ||
    Seed.textWide ||
    Seed.textBoxWide ||
    Seed.musicWide ||
    Seed.photoWide => const [TestClip.blue, TestClip.red],
    Seed.threeClips => const [TestClip.blue, TestClip.red, TestClip.green],
  };

  /// The text a start on the seed has selected.
  TextID? get selectedText => switch (this) {
    Seed.empty || Seed.twoClips || Seed.threeClips || Seed.twoClipsWide || Seed.musicWide || Seed.photoWide => null,
    Seed.textWide || Seed.textBoxWide => const TextID(1),
  };

  /// The tone files a start on the seed needs.
  List<TestTone> get testTones => this == Seed.musicWide ? const [TestTone.long] : const [];

  /// The test photos a start on the seed needs.
  List<TestPhoto> get testPhotos => this == Seed.photoWide ? const [TestPhoto.magenta] : const [];

  /// A start on the seed has the sound panel open.
  bool get showsSound => this == Seed.musicWide;

  /// Each clip whole, from its first frame, on the seed's canvas. A text seed has one text, id 1.
  /// The music seed has the long tone as its music. The photo seed has its photo between its two clips, for
  /// photoLength.
  Project get project {
    final infos = testClips.map((clip) => clip.info).toList();
    if (this == Seed.photoWide) {
      infos.insert(1, TestPhoto.magenta.info);
    }
    final media = <MediaID, MediaInfo>{};
    final clips = <Clip>[];
    var nextClipID = 1;
    for (final info in infos) {
      final duration = info.kind == MediaKind.photo ? MediaInfo.photoLength : info.duration;
      media[info.id] = info;
      clips.add(Clip(id: ClipID(nextClipID), media: info.id, sourceStart: Time.zero, duration: duration));
      nextClipID += 1;
    }
    final project = Project(canvas: canvas).copyWith(clips: clips, media: media, nextClipID: nextClipID);
    switch (this) {
      case Seed.empty || Seed.twoClips || Seed.threeClips || Seed.twoClipsWide || Seed.photoWide:
        return project;
      case Seed.musicWide:
        return project.copyWith(music: () => Music.file(TestTone.long.file));
      case Seed.textWide:
        // The middle line is Arabic with every vowel mark, written as scalars so no editor reorders it.
        const arabic =
            '\u0627\u0644\u0633\u0651\u064E\u0644\u064E\u0627\u0645\u064F\u0020'
            '\u0639\u064E\u0644\u064E\u064A\u0652\u0643\u064F\u0645\u0652';
        return project.copyWith(
          texts: [
            const TextItem(
              id: TextID(1),
              string: 'Peace\n$arabic\nbe upon you',
              span: TextSpan.whole,
              x: 960,
              y: 540,
              rotation: 0,
              style: TextStyle.standard,
            ),
          ],
          nextTextID: 2,
        );
      case Seed.textBoxWide:
        return project.copyWith(
          texts: [
            TextItem(
              id: const TextID(1),
              string: 'BOX',
              span: const TextSpan.range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900))),
              x: 960,
              y: 540,
              rotation: 0,
              style: TextStyle.standard.copyWith(size: 96, colour: const RGB(r: 255, g: 214, b: 10), box: true),
            ),
          ],
          nextTextID: 2,
        );
    }
  }
}
