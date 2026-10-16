import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import 'text_model_test.dart' show textItem;

/// A music file of that length, for a length no test tone has.
MusicFile musicFile(int ticks) =>
    MusicFile(id: const MediaID('file'), fileName: 'file.m4a', title: 'file', duration: Time(ticks: ticks));

void main() {
  test('testANewProjectHasFullClipSoundNoMuteAndNoMusic', () {
    for (final project in [const Project(), const Project(canvas: Canvas.landscape)]) {
      expect(project.clipVolume, 1);
      expect(project.clipsMuted, isFalse);
      expect(project.music, isNull);
    }
  });

  test('testAMusicMadeFromAFileBeginsAtZeroAtFullVolumeWithNoFade', () {
    final file = TestTone.long.file;

    expect(Music.file(file), Music(file: file, start: Time.zero, volume: 1, fadeIn: Time.zero, fadeOut: Time.zero));
  });

  test('testTheLimitsOfSoundAreFiveSecondsOfFadeOneSecondOfMusicAndAStepOfOneSecond', () {
    expect(SoundGeometry.maximumFade, const Time(ticks: 3000));
    expect(SoundGeometry.minimumMusic, const Time(ticks: 600));
    expect(SoundGeometry.startStep, const Time(ticks: 600));
  });

  test('testTheLargestStartLeavesOneSecondOfTheFileAndIsAWholeFrame', () {
    expect(Music.file(TestTone.long.file).largestStart, const Time(ticks: 5400));
    expect(Music.file(TestTone.short.file).largestStart, const Time(ticks: 600));
    expect(Music.file(musicFile(900)).largestStart, const Time(ticks: 300));
    expect(Music.file(musicFile(6010)).largestStart, const Time(ticks: 5400));
  });

  test('testTheLargestStartIsZeroForAFileNotLongerThanOneSecond', () {
    expect(Music.file(musicFile(600)).largestStart, Time.zero);
    expect(Music.file(musicFile(500)).largestStart, Time.zero);
  });

  test('testTheMusicIsHeardForTheSmallerOfWhatIsLeftOfTheFileAndTheProjectLength', () {
    expect(Seed.musicWide.project.heardMusic, const Time(ticks: 4200));

    final seed = Seed.musicWide.project;
    final blueAlone = seed.copyWith(clips: seed.clips.sublist(0, seed.clips.length - 1));
    expect(blueAlone.heardMusic, const Time(ticks: 1800));

    final lateStart = seed.copyWith(music: () => seed.music?.copyWith(start: const Time(ticks: 5400)));
    expect(lateStart.heardMusic, const Time(ticks: 600));

    final shortFile = seed.copyWith(music: () => Music.file(TestTone.short.file));
    expect(shortFile.heardMusic, const Time(ticks: 1200));
  });

  test('testNothingIsHeardWithNoMusicAndWithNoClip', () {
    expect(Seed.twoClipsWide.project.heardMusic, isNull);

    final noClip = Seed.musicWide.project.copyWith(clips: []);
    expect(noClip.music, isNotNull);
    expect(noClip.heardMusic, isNull);
  });

  test('testEachValueOfSoundAloneMakesAnotherFootage', () {
    final seed = Seed.musicWide.project;
    final changes = <(String, Project)>[
      ('clipVolume', seed.copyWith(clipVolume: 0.5)),
      ('clipsMuted', seed.copyWith(clipsMuted: true)),
      ('no music', seed.copyWith(music: () => null)),
      ('the volume of the music', seed.copyWith(music: () => seed.music?.copyWith(volume: 0.5))),
      ('the start', seed.copyWith(music: () => seed.music?.copyWith(start: const Time(ticks: 600)))),
      ('the fade in', seed.copyWith(music: () => seed.music?.copyWith(fadeIn: const Time(ticks: 300)))),
      ('the fade out', seed.copyWith(music: () => seed.music?.copyWith(fadeOut: const Time(ticks: 300)))),
    ];

    expect(seed.sameFootage(seed), isTrue);
    for (final (name, changed) in changes) {
      expect(changed, isNot(seed), reason: name);
      expect(seed.sameFootage(changed), isFalse, reason: name);
      expect(changed.sameFootage(seed), isFalse, reason: name);
    }
  });

  test('testProjectsWithMusicThatDifferOnlyInTheirTextsAreTheSameFootage', () {
    final seed = Seed.musicWide.project;
    final withText = seed.copyWith(texts: [textItem(1, 'Hello', TextSpan.whole)], nextTextID: 2);

    expect(withText, isNot(seed));
    expect(seed.sameFootage(withText), isTrue);
  });
}
