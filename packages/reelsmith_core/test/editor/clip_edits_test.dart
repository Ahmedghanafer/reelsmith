import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// testAMoveOfGreenToTheFirstPlaceSelectsItKeepsThePlayheadPausesAndUndoesInOneStep is ported with Editing.
void main() {
  const blue = ClipID(1);
  const red = ClipID(2);
  const green = ClipID(3);

  List<String> order(EditorState state) => state.project.clips.map((clip) => clip.media.raw).toList();

  /// Three clips, playing, with the playhead at the time given.
  EditorState playing(int ticks, {ClipID? selected}) => EditorState(
    Seed.threeClips.project,
  ).copyWith(playhead: Time(ticks: ticks), selection: () => selected, isPlaying: true);

  test('testAMoveIsHeldBetweenTheFirstAndTheLastPlace', () {
    final start = playing(600);

    expect(order(reduce(start, EditorAction.moveClip(green, 0))), ['green', 'blue', 'red']);
    expect(order(reduce(start, EditorAction.moveClip(blue, 9))), ['red', 'green', 'blue']);
  });

  test('testAMoveToItsOwnPlaceOfAnUnknownIdOrOnAnEmptyProjectReturnsTheStateUnchanged', () {
    final start = playing(600);
    final empty = EditorState(Seed.empty.project).copyWith(isPlaying: true);

    expect(reduce(start, EditorAction.moveClip(red, 2)), start);
    expect(reduce(start, EditorAction.moveClip(const ClipID(9), 1)), start);
    expect(reduce(empty, EditorAction.moveClip(blue, 1)), empty);
  });

  test('testAMoveKeepsEveryTextItsRangeAndTheVolumeOfEachClip', () {
    var start = playing(600);
    start = reduce(start, EditorAction.sound(SoundAction.setVolumeOfClip(red, 0.4)));
    start = start.copyWith(
      project: start.project.copyWith(
        texts: [
          const TextItem(
            id: TextID(1),
            string: 'One',
            span: TextSpan.range(TextRange(start: Time(ticks: 300), duration: Time(ticks: 900))),
            x: 540,
            y: 960,
            rotation: 0,
            style: TextStyle.standard,
          ),
          const TextItem(
            id: TextID(2),
            string: 'Two',
            span: TextSpan.whole,
            x: 540,
            y: 400,
            rotation: 0,
            style: TextStyle.standard,
          ),
        ],
        nextTextID: 3,
      ),
    );

    final moved = reduce(start, EditorAction.moveClip(green, 1));

    expect(moved.project.texts, start.project.texts);
    expect(moved.project.range(const TextID(1)), start.project.range(const TextID(1)));
    expect(moved.project.range(const TextID(2)), start.project.range(const TextID(2)));
    expect(moved.project.clips.map((clip) => clip.volume).toList(), [1, 1, 0.4]);
  });

  test('testBothCutsAtSixHundredInsideBlue', () {
    final start = playing(600, selected: blue);
    expect(start.canCutBefore, isTrue);
    expect(start.canCutAfter, isTrue);

    final before = reduce(start, EditorAction.cutBefore);
    expect(
      before.project.clips[0],
      const Clip(id: blue, media: MediaID('blue'), sourceStart: Time(ticks: 600), duration: Time(ticks: 1200)),
    );
    expect(before.playhead, Time.zero);
    expect(before.selection, blue);
    expect(before.isPlaying, isFalse);

    final after = reduce(start, EditorAction.cutAfter);
    expect(
      after.project.clips[0],
      const Clip(id: blue, media: MediaID('blue'), sourceStart: Time.zero, duration: Time(ticks: 600)),
    );
    expect(after.playhead, const Time(ticks: 600));
    expect(after.selection, blue);
    expect(after.isPlaying, isFalse);
  });

  test('testNeitherCutNearTheEndsOfBlueInRedWithBlueSelectedOrWithNoSelection', () {
    final states = [playing(40, selected: blue), playing(1760, selected: blue), playing(2400, selected: blue), playing(600)];
    for (final state in states) {
      final reason = 'playhead ${state.playhead.ticks}';
      expect(state.canCutBefore, isFalse, reason: reason);
      expect(state.canCutAfter, isFalse, reason: reason);
      expect(reduce(state, EditorAction.cutBefore), state, reason: reason);
      expect(reduce(state, EditorAction.cutAfter), state, reason: reason);
    }
  });

  test('testBothCutsOfThePhotoOfPhotoWide', () {
    const photo = ClipID(2);
    final start = EditorState(
      Seed.photoWide.project,
    ).copyWith(selection: () => photo, playhead: const Time(ticks: 2400), isPlaying: true);
    expect(start.canCutBefore, isTrue);
    expect(start.canCutAfter, isTrue);

    final before = reduce(start, EditorAction.cutBefore);
    expect(
      before.project.clips[1],
      const Clip(id: photo, media: MediaID('magenta'), sourceStart: Time(ticks: 600), duration: Time(ticks: 1200)),
    );
    expect(before.playhead, const Time(ticks: 1800));
    expect(before.selection, photo);
    expect(before.isPlaying, isFalse);

    final after = reduce(start, EditorAction.cutAfter);
    expect(
      after.project.clips[1],
      const Clip(id: photo, media: MediaID('magenta'), sourceStart: Time.zero, duration: Time(ticks: 600)),
    );
    expect(after.playhead, const Time(ticks: 2400));
    expect(after.selection, photo);
    expect(after.isPlaying, isFalse);
  });

  test('testTheDropPositionOfRedAmongBlueAndGreen', () {
    final project = Seed.threeClips.project;

    expect(project.dropPosition(of: red, at: const Time(ticks: 0)), 1);
    expect(project.dropPosition(of: red, at: const Time(ticks: 800)), 1);
    expect(project.dropPosition(of: red, at: const Time(ticks: 1000)), 2);
    expect(project.dropPosition(of: red, at: const Time(ticks: 2500)), 3);
    expect(project.dropPosition(of: const ClipID(9), at: const Time(ticks: 800)), isNull);
  });

  test('testTheClipPanelShowsForASelectedClipOnly', () {
    final none = EditorState(Seed.threeClips.project);
    final selected = reduce(none, EditorAction.select(blue));
    final text = EditorState(Seed.textWide.project).copyWith(selectedText: () => Seed.textWide.selectedText);

    expect(selected.showsClipPanel, isTrue);
    expect(none.showsClipPanel, isFalse);
    expect(text.showsClipPanel, isFalse);
    expect(reduce(selected, EditorAction.sound(SoundAction.open)).showsClipPanel, isFalse);
    expect(reduce(selected, EditorAction.deleteSelected).showsClipPanel, isFalse);
  });

  test('testTheVolumeOfTheClipShowsForABlueSelectedAndNotForThePhoto', () {
    final blueSelected = reduce(EditorState(Seed.threeClips.project), EditorAction.select(blue));
    final photoSelected = reduce(EditorState(Seed.photoWide.project), EditorAction.select(const ClipID(2)));

    expect(blueSelected.showsClipVolume, isTrue);
    expect(photoSelected.showsClipPanel, isTrue);
    expect(photoSelected.showsClipVolume, isFalse);
  });
}
