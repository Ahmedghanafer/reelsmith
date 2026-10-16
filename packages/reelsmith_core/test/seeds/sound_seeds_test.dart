import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testTheTwoTestTonesHoldTheValuesOfTheTable', () {
    expect(
      TestTone.long,
      const TestTone(
        name: 'long-tone',
        duration: Time(ticks: 6000),
        firstHertz: 880,
        secondHertz: 1320,
        peak: 0.25,
        sampleRate: 44100,
        channels: 1,
      ),
    );
    expect(
      TestTone.short,
      const TestTone(
        name: 'short-tone',
        duration: Time(ticks: 1200),
        firstHertz: 660,
        secondHertz: 660,
        peak: 0.25,
        sampleRate: 44100,
        channels: 1,
      ),
    );
    expect(TestTone.all, [TestTone.long, TestTone.short]);
  });

  test('testTheFileOfATestToneHasTheIdTheFileNameAndTheTitleOfItsName', () {
    expect(
      TestTone.long.file,
      const MusicFile(
        id: MediaID('long-tone'),
        fileName: 'long-tone.mov',
        title: 'long-tone',
        duration: Time(ticks: 6000),
      ),
    );
    expect(
      TestTone.short.file,
      const MusicFile(
        id: MediaID('short-tone'),
        fileName: 'short-tone.mov',
        title: 'short-tone',
        duration: Time(ticks: 1200),
      ),
    );
  });

  test('testTheMusicSeedIsTheWideSeedWithTheLongToneAsItsMusic', () {
    final wanted = Seed.twoClipsWide.project.copyWith(music: () => Music.file(TestTone.long.file));

    expect(Seed.fromRawValue('music-wide'), Seed.musicWide);
    expect(Seed.musicWide.project, wanted);
    expect(Seed.musicWide.canvas, Canvas.landscape);
    expect(Seed.musicWide.testClips, [TestClip.blue, TestClip.red]);
    expect(Seed.musicWide.selectedText, isNull);
    expect(Seed.musicWide.testTones, [TestTone.long]);
    expect(Seed.musicWide.showsSound, isTrue);
  });

  test('testTheOtherSevenSeedsHaveNoTestToneAndDoNotShowTheSoundPanel', () {
    const others = [
      Seed.empty,
      Seed.twoClips,
      Seed.threeClips,
      Seed.twoClipsWide,
      Seed.textWide,
      Seed.textBoxWide,
      Seed.photoWide,
    ];

    expect(Seed.allCases.toSet(), {...others, Seed.musicWide});
    for (final seed in others) {
      expect(seed.testTones, <TestTone>[], reason: seed.rawValue);
      expect(seed.showsSound, isFalse, reason: seed.rawValue);
    }
  });
}
