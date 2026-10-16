import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testANewStateHasNoSelectionThePlayheadAtZeroAndIsNotPlaying', () {
    final state = EditorState(Seed.twoClips.project);

    expect(state.project, Seed.twoClips.project);
    expect(state.selection, isNull);
    expect(state.playhead, Time.zero);
    expect(state.isPlaying, isFalse);
  });

  test('testTimeLabelOfTwoClipsReadsPlayheadAndLength', () {
    expect(EditorState(Seed.twoClips.project).timeLabel, '00:00 / 00:07');
  });

  test('testCanPlayAndCanExportOnlyWhenTheProjectHasClips', () {
    final empty = EditorState(Seed.empty.project);
    expect(empty.canPlay, isFalse);
    expect(empty.canExport, isFalse);

    for (final seed in [Seed.twoClips, Seed.threeClips]) {
      final state = EditorState(seed.project);
      expect(state.canPlay, isTrue, reason: seed.rawValue);
      expect(state.canExport, isTrue, reason: seed.rawValue);
    }
  });
}
