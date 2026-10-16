import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/sound_model_test.dart' show musicFile;

void main() {
  EditorState state(Project Function(Project) change) => EditorState(change(Seed.musicWide.project));

  /// Every value of sound away from the one a new music has.
  Project changed(Project project) => project.copyWith(
    clipVolume: 0.5,
    clipsMuted: true,
    music: () => project.music?.copyWith(
      start: const Time(ticks: 600),
      volume: 0.25,
      fadeIn: const Time(ticks: 300),
      fadeOut: const Time(ticks: 3000),
    ),
  );

  test('testANewStateDoesNotShowTheSoundPanel', () {
    expect(EditorState(Seed.musicWide.project).showsSound, isFalse);
    expect(EditorState(Seed.empty.project).showsSound, isFalse);
  });

  test('testTheSoundPanelCanOpenOnlyOnAProjectWithAClip', () {
    expect(EditorState(Seed.twoClipsWide.project).canOpenSound, isTrue);
    expect(EditorState(Seed.empty.project).canOpenSound, isFalse);
  });

  test('testClearSelectionClosesTheSoundPanel', () {
    final open = EditorState(Seed.musicWide.project).copyWith(showsSound: true);

    expect(reduce(open, EditorAction.clearSelection).showsSound, isFalse);
  });

  test('testTheStartCanBeSetOnlyWhenAStepFitsBeforeTheLargestStart', () {
    expect(EditorState(Seed.musicWide.project).canSetMusicStart, isTrue);
    expect(state((project) => project.copyWith(music: () => Music.file(TestTone.short.file))).canSetMusicStart, isTrue);
    expect(state((project) => project.copyWith(music: () => Music.file(musicFile(900)))).canSetMusicStart, isFalse);
    expect(EditorState(Seed.twoClipsWide.project).canSetMusicStart, isFalse);
  });

  test('testSoundInfoOfTheTwoSeeds', () {
    expect(EditorState(Seed.twoClipsWide.project).soundInfo, '100 . none');
    expect(EditorState(Seed.musicWide.project).soundInfo, '100 . 0+4200 100 0 0');
  });

  test('testSoundInfoReadsEveryValueWithTheFadesAsStored', () {
    expect(state(changed).soundInfo, '50 m 600+4200 25 300 3000');
  });

  test('testSoundInfoReadsHiddenForMusicWithNoClip', () {
    final noClip = state((project) => changed(project).copyWith(clips: []));

    expect(noClip.soundInfo, '50 m hidden 25 300 3000');
  });

  test('testTheMusicLabelGivesTheTimesHeardOfTheFileAndItsLength', () {
    expect(EditorState(Seed.musicWide.project).musicLabel, '00:00-00:07 / 00:10');
    expect(
      state((project) => project.copyWith(music: () => project.music?.copyWith(start: const Time(ticks: 3000)))).musicLabel,
      '00:05-00:10 / 00:10',
    );
  });

  test('testThereIsNoMusicLabelWithNoMusicAndWithNoClip', () {
    expect(EditorState(Seed.twoClipsWide.project).musicLabel, isNull);
    expect(state((project) => project.copyWith(clips: [])).musicLabel, isNull);
  });
}
