import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  /// The editing a start on the seed begins with: its project, its selected text and its sound panel.
  Editing start(Seed seed) => Editing(
    EditorState(seed.project).copyWith(selectedText: () => seed.selectedText, showsSound: seed.showsSound),
  );

  Editing sent(Editing editing, List<EditorAction> actions) {
    var next = editing;
    for (final action in actions) {
      next = next.after(action);
    }
    return next;
  }

  EditorAction move(double x) => EditorAction.text(TextAction.move(const TextID(1), x, 100));

  EditorAction style(TextStyle Function(TextStyle) change, Editing editing) {
    final style = change(editing.state.project.text(const TextID(1))!.style);
    return EditorAction.text(TextAction.setStyle(const TextID(1), style));
  }

  test('testADeleteIsUndoneAndRedone', () {
    final deleted = sent(start(Seed.twoClipsWide), [
      EditorAction.select(const ClipID(2)),
      EditorAction.deleteSelected,
    ]);
    expect(deleted.state.project.clips.length, 1);
    expect(deleted.canUndo, isTrue);
    expect(deleted.canRedo, isFalse);

    final undone = deleted.undone();
    expect(undone.state.project.clips, Seed.twoClipsWide.project.clips);
    expect(undone.canRedo, isTrue);
    expect(undone.canUndo, isFalse);

    final redone = undone.redone();
    expect(redone.state.project.clips.map((clip) => clip.id).toList(), [const ClipID(1)]);

    expect(undone.undone(), undone);
    expect(deleted.redone(), deleted);
  });

  test('testEightTypedStringsAreOneStepAndWriteOnlyAfterTheRun', () {
    final seedString = Seed.textWide.project.text(const TextID(1))!.string;
    var editing = start(Seed.textWide);
    for (var count = 1; count <= 8; count++) {
      final string = 'Hello wo'.substring(0, count);
      editing = editing.after(EditorAction.text(TextAction.setString(const TextID(1), string)));
      expect(editing.writesNow, isFalse);
    }
    expect(editing.state.project.text(const TextID(1))?.string, 'Hello wo');
    expect(editing.history.past.length, 1);
    expect(editing.undone().state.project.text(const TextID(1))?.string, seedString);

    editing = editing.after(EditorAction.clearSelection);
    expect(editing.writesNow, isTrue);
    expect(editing.history.past.length, 1);
  });

  test('testEachGestureIsOneStep', () {
    var editing = start(Seed.textWide);
    editing = editing.after(EditorAction.pause);
    editing = sent(editing, [for (var i = 1; i <= 20; i++) move(100 + i.toDouble())]);
    expect(editing.history.past.length, 1);

    editing = editing.after(EditorAction.pause);
    editing = sent(editing, [for (var i = 1; i <= 20; i++) move(300 + i.toDouble())]);
    expect(editing.history.past.length, 2);

    editing = editing.after(EditorAction.pause);
    for (var count = 1; count <= 10; count++) {
      editing = editing.after(style((style) => style.copyWith(size: 70 + count.toDouble()), editing));
    }
    expect(editing.state.project.text(const TextID(1))?.style.size, 80);
    expect(editing.history.past.length, 3);

    editing = editing.after(EditorAction.pause);
    editing = sent(editing, [for (var i = 1; i <= 10; i++) move(500 + i.toDouble())]);
    editing = sent(editing, [
      for (var i = 1; i <= 10; i++) EditorAction.text(TextAction.turn(const TextID(1), 10 + i.toDouble())),
    ]);
    expect(editing.state.project.text(const TextID(1))?.rotation, 20);
    expect(editing.history.past.length, 4);
  });

  test('testTwoTogglesAndAFontAreStepsOfTheirOwn', () {
    var editing = start(Seed.textWide);
    editing = editing.after(style((style) => style.copyWith(box: true), editing));
    expect(editing.history.past.length, 1);
    editing = editing.after(style((style) => style.copyWith(shadow: true), editing));
    expect(editing.history.past.length, 2);

    editing = editing.after(style((style) => style.copyWith(size: 80), editing));
    expect(editing.history.past.length, 3);
    editing = editing.after(style((style) => style.copyWith(font: TextFont.naskhBold), editing));
    expect(editing.history.past.length, 4);
    editing = editing.after(style((style) => style.copyWith(size: 90), editing));
    expect(editing.history.past.length, 5);

    expect(editing.undone().undone().state.project.text(const TextID(1))?.style.font, TextFont.naskh);
  });

  test('testATextLeftBlankIsNoStepAndKeepsItsID', () {
    var editing = start(Seed.textWide);
    editing = sent(editing, [EditorAction.text(TextAction.add), EditorAction.clearSelection]);
    expect(editing.canUndo, isFalse);
    expect(editing.unsaved, isFalse);
    expect(editing.state.project.texts.map((text) => text.id).toList(), [const TextID(1)]);
    expect(editing.state.project.nextTextID, 3);

    editing = editing.after(EditorAction.text(TextAction.add));
    expect(editing.state.selectedText, const TextID(3));
    expect(editing.state.project.texts.map((text) => text.id).toList(), [const TextID(1), const TextID(3)]);

    final noSteps = <EditorAction>[
      EditorAction.movePlayhead(const Time(ticks: 900)),
      EditorAction.play,
      EditorAction.pause,
      EditorAction.select(const ClipID(1)),
      EditorAction.text(TextAction.select(const TextID(1))),
      EditorAction.sound(SoundAction.open),
    ];
    editing = sent(editing, noSteps);
    expect(editing.canUndo, isFalse);
    expect(editing.unsaved, isFalse);

    final typed = sent(start(Seed.textWide), [
      EditorAction.text(TextAction.add),
      EditorAction.text(TextAction.setString(const TextID(2), 'A')),
    ]);
    expect(typed.history.past.length, 1);
    expect(typed.state.project.texts.map((text) => text.string).last, 'A');
    expect(typed.undone().state.project.texts, Seed.textWide.project.texts);
  });

  test('testUndoAndRedoKeepOnlyWhatIsStillThere', () {
    var editing = sent(start(Seed.twoClipsWide), [
      EditorAction.select(const ClipID(2)),
      EditorAction.deleteSelected,
      EditorAction.select(const ClipID(1)),
      EditorAction.play,
    ]);
    expect(editing.state.isPlaying, isTrue);
    editing = editing.undone();
    expect(editing.state.project.clips.length, 2);
    expect(editing.state.selection, const ClipID(1));
    expect(editing.state.isPlaying, isFalse);

    editing = sent(editing, [EditorAction.select(const ClipID(2)), EditorAction.play]);
    editing = editing.redone();
    expect(editing.state.project.clips.map((clip) => clip.id).toList(), [const ClipID(1)]);
    expect(editing.state.selection, isNull);
    expect(editing.state.isPlaying, isFalse);

    editing = editing.undone();
    editing = editing.after(EditorAction.movePlayhead(const Time(ticks: 4000)));
    expect(editing.state.playhead, const Time(ticks: 4000));
    expect(editing.canRedo, isTrue);
    editing = editing.redone();
    expect(editing.state.playhead, const Time(ticks: 1800));

    var text = sent(start(Seed.textWide), [EditorAction.deleteSelected]);
    expect(text.state.project.texts, <TextItem>[]);
    text = text.undone();
    expect(text.state.project.texts, Seed.textWide.project.texts);
    text = sent(text, [EditorAction.text(TextAction.select(const TextID(1))), EditorAction.play]);
    text = text.redone();
    expect(text.state.selectedText, isNull);
    expect(text.state.isPlaying, isFalse);

    var empty = sent(start(Seed.twoClipsWide), [
      EditorAction.select(const ClipID(2)),
      EditorAction.deleteSelected,
      EditorAction.select(const ClipID(1)),
      EditorAction.deleteSelected,
    ]);
    expect(empty.state.project.clips, <Clip>[]);
    empty = empty.undone().after(EditorAction.sound(SoundAction.open));
    expect(empty.state.showsSound, isTrue);
    empty = empty.undone();
    expect(empty.state.project.clips.length, 2);
    expect(empty.state.showsSound, isTrue);
    empty = empty.redone().redone();
    expect(empty.state.project.clips, <Clip>[]);
    expect(empty.state.showsSound, isFalse);
  });

  test('testFiftyStepsAreKeptAndANewStepEndsTheFuture', () {
    var editing = start(Seed.twoClipsWide);
    for (var count = 1; count <= 51; count++) {
      editing = editing.after(EditorAction.sound(SoundAction.setClipVolume(count / 100)));
    }
    expect(UndoHistory.depth, 50);
    expect(editing.history.past.length, 50);
    expect(editing.history.past.first.clipVolume, 1.0 / 100);
    expect(editing.history.past.last.clipVolume, 50.0 / 100);

    editing = editing.undone().undone();
    expect(editing.history.future.length, 2);
    editing = editing.after(EditorAction.sound(const SoundAction.muteClips(true)));
    expect(editing.history.future, <Project>[]);
    expect(editing.canRedo, isFalse);
    expect(editing.history.past.length, 49);
  });

  test('testUnsavedFollowsTheChangesAndTheWrites', () {
    var editing = start(Seed.twoClipsWide);
    expect(editing.unsaved, isFalse);
    editing = editing.after(EditorAction.sound(const SoundAction.muteClips(true)));
    expect(editing.unsaved, isTrue);
    expect(editing.writesNow, isTrue);
    editing = editing.written();
    expect(editing.unsaved, isFalse);
    expect(editing.writesNow, isFalse);
    expect(editing.canUndo, isTrue);

    editing = editing.undone();
    expect(editing.unsaved, isTrue);
    editing = editing.written().redone();
    expect(editing.unsaved, isTrue);
    editing = editing.written();

    editing = sent(editing, [
      EditorAction.movePlayhead(const Time(ticks: 600)),
      EditorAction.play,
      EditorAction.pause,
      EditorAction.select(const ClipID(1)),
    ]);
    expect(editing.unsaved, isFalse);
  });
}
