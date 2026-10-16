import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/text_model_test.dart' show arabicLineScalars;

// testTheTwoTextSeedsAreReadFromTheirNames stays in Swift: it reads LaunchOptions.
void main() {
  test('testATextSeedHasTheClipsOfTheWideSeedAndOneText', () {
    for (final seed in [Seed.textWide, Seed.textBoxWide]) {
      final project = seed.project;

      expect(seed.testClips, [TestClip.blue, TestClip.red]);
      expect(project.canvas, Canvas.landscape);
      expect(project.clips, Seed.twoClipsWide.project.clips);
      expect(project.media, Seed.twoClipsWide.project.media);
      expect(project.clips.map((clip) => clip.id).toList(), [const ClipID(1), const ClipID(2)]);
      expect(project.clips.map((clip) => clip.media).toList(), [const MediaID('blue'), const MediaID('red')]);
      expect(project.nextClipID, 3);
      expect(project.duration, const Time(ticks: 4200));
      expect(project.texts.map((text) => text.id).toList(), [const TextID(1)]);
      expect(project.nextTextID, 2);
    }
  });

  test('testTheOtherFourSeedsHaveNoText', () {
    for (final seed in [Seed.empty, Seed.twoClips, Seed.threeClips, Seed.twoClipsWide]) {
      expect(seed.project.texts, <TextItem>[]);
      expect(seed.project.nextTextID, 1);
      expect(seed.selectedText, isNull);
    }
  });

  test('testATextSeedStartsWithItsTextSelected', () {
    expect(Seed.textWide.selectedText, const TextID(1));
    expect(Seed.textBoxWide.selectedText, const TextID(1));
  });

  test('testTheWholeTextSeedHoldsThreeLinesWithTheArabicLineBetween', () {
    final texts = Seed.textWide.project.texts;
    expect(texts, isNotEmpty);
    final text = texts.first;
    final lines = text.string.split('\n');

    expect(lines.length, 3);
    expect(lines.first, 'Peace');
    expect(lines.last, 'be upon you');
    expect(arabicLineScalars.length, 21);
    expect(lines[1].runes.toList(), arabicLineScalars);
    expect(text.span, TextSpan.whole);
    expect(text.x, 960);
    expect(text.y, 540);
    expect(text.rotation, 0);
    expect(text.style, TextStyle.standard);
    expect(text.style.size, 64);
  });

  test('testTheBoxedTextSeedHoldsOneYellowBoxedWordForAPartOfTheFirstClip', () {
    final style = TextStyle.standard.copyWith(size: 96, colour: const RGB(r: 255, g: 214, b: 10), box: true);

    expect(Seed.textBoxWide.project.texts, [
      TextItem(
        id: const TextID(1),
        string: 'BOX',
        span: const TextSpan.range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900))),
        x: 960,
        y: 540,
        rotation: 0,
        style: style,
      ),
    ]);
  });
}
