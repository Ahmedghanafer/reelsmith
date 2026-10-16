import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  final twoClips = EditorState(Seed.twoClips.project);

  test('testSelectOfAClipOfTheProjectSetsTheSelection', () {
    expect(reduce(twoClips, EditorAction.select(const ClipID(2))).selection, const ClipID(2));
  });

  test('testSelectOfAnUnknownIdReturnsTheStateUnchanged', () {
    final state = twoClips.copyWith(selection: () => const ClipID(1));

    expect(reduce(state, EditorAction.select(const ClipID(9))), state);
  });

  test('testClearSelectionEmptiesIt', () {
    final state = twoClips.copyWith(selection: () => const ClipID(1));

    expect(reduce(state, EditorAction.clearSelection).selection, isNull);
  });

  test('testMovePlayheadRoundsDownToAFrameAndStaysInsideTheProject', () {
    expect(reduce(twoClips, EditorAction.movePlayhead(const Time(ticks: 4205))).playhead, const Time(ticks: 4200));
    expect(reduce(twoClips, EditorAction.movePlayhead(const Time(ticks: -40))).playhead, const Time(ticks: 0));
    expect(reduce(twoClips, EditorAction.movePlayhead(const Time(ticks: 9999))).playhead, const Time(ticks: 4200));
    expect(reduce(twoClips, EditorAction.movePlayhead(const Time(ticks: 1239))).playhead, const Time(ticks: 1220));
  });

  test('testMovePlayheadLeavesIsPlayingAlone', () {
    final playing = twoClips.copyWith(isPlaying: true);

    expect(reduce(playing, EditorAction.movePlayhead(const Time(ticks: 600))).isPlaying, isTrue);
    expect(reduce(twoClips, EditorAction.movePlayhead(const Time(ticks: 600))).isPlaying, isFalse);
  });

  test('testPlaySetsIsPlayingAndKeepsThePlayhead', () {
    final state = twoClips.copyWith(playhead: const Time(ticks: 600));

    final next = reduce(state, EditorAction.play);

    expect(next.isPlaying, isTrue);
    expect(next.playhead, const Time(ticks: 600));
  });

  test('testPlayAtTheEndStartsFromZero', () {
    final state = twoClips.copyWith(playhead: const Time(ticks: 4200));

    final next = reduce(state, EditorAction.play);

    expect(next.isPlaying, isTrue);
    expect(next.playhead, Time.zero);
  });

  test('testPlayDoesNothingOnAnEmptyProject', () {
    final empty = EditorState(Seed.empty.project);

    expect(reduce(empty, EditorAction.play), empty);
  });

  test('testPauseClearsIsPlaying', () {
    final state = twoClips.copyWith(isPlaying: true);

    expect(reduce(state, EditorAction.pause).isPlaying, isFalse);
  });
}
