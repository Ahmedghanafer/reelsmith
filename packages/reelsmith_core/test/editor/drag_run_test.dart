import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  /// The editing of a start on music-wide with the video playing.
  Editing playing() =>
      Editing(EditorState(Seed.musicWide.project).copyWith(showsSound: Seed.musicWide.showsSound)).after(
        EditorAction.play,
      );

  /// Drag steps of the volume of the clips, each followed by a report of the playhead as the player sends it
  /// while playing.
  Editing dragged(Editing editing, List<double> volumes, int tick) {
    var next = editing;
    for (var index = 0; index < volumes.length; index++) {
      next = next.afterDragStep(EditorAction.sound(SoundAction.setClipVolume(volumes[index])));
      next = next.after(EditorAction.movePlayhead(Time(ticks: tick + (index + 1) * 20)));
    }
    return next;
  }

  test('testADragWhilePlayingIsOneStepAndWritesOnlyAtItsEnd', () {
    final start = playing();
    expect(start.state.isPlaying, isTrue);
    var editing = dragged(start, [0.9, 0.8, 0.7], 0);
    expect(editing.state.project.clipVolume, 0.7);
    expect(editing.history.past.length, 1);
    expect(editing.unsaved, isTrue);
    expect(editing.writesNow, isFalse);

    editing = editing.endingRun();
    expect(editing.writesNow, isTrue);
    expect(editing.history.past.length, 1);
    expect(editing.undone().state.project.clipVolume, 1);

    editing = dragged(editing.written(), [0.6, 0.5], 100).endingRun();
    expect(editing.history.past.length, 2);
    expect(editing.history.past.last.clipVolume, 0.7);
  });

  test('testAChangeOfAnotherKindEndsTheRunAndNoChangeLeavesItOpen', () {
    final open = playing().afterDragStep(EditorAction.sound(SoundAction.setClipVolume(0.5)));
    expect(open.history.run, EditRun.drag);

    final selected = open
        .after(EditorAction.select(const ClipID(1)))
        .after(EditorAction.movePlayhead(const Time(ticks: 300)));
    expect(selected.history.run, EditRun.drag);
    expect(selected.writesNow, isFalse);

    final muted = open.after(EditorAction.sound(SoundAction.muteClips(true)));
    expect(muted.history.run, isNull);
    expect(muted.history.past.length, 2);
    expect(muted.writesNow, isTrue);

    expect(open.undone().history.run, isNull);
    final again = open.undone().redone();
    expect(again.history.run, isNull);

    // A level sent by after is a step of its own, also during a drag run.
    final sent = open.after(EditorAction.sound(SoundAction.setClipVolume(0.4)));
    expect(sent.history.run, isNull);
    expect(sent.history.past.length, 2);
  });

  /// A drag that ends where it began, as a pinch that zooms a clip above 1 and back to 1, leaves no step.
  test('testADragThatEndsOnTheProjectItBeganWithLeavesNoStep', () {
    final start = playing().afterDragStep(EditorAction.sound(SoundAction.setClipVolume(0.5))).endingRun();
    expect(start.history.past.length, 1);

    final back = dragged(start, [0.4, 0.5], 0).endingRun();
    expect(back.state.project, start.state.project);
    expect(back.history.past, start.history.past);
    expect(back.history.run, isNull);
    expect(back.undone().state.project.clipVolume, 1);

    // A drag that changes the project keeps its one step.
    final moved = dragged(start, [0.4, 0.3], 0).endingRun();
    expect(moved.history.past.length, 2);
  });

  test('testADraftWithAnOpenDragRunRoundTripsAndOpensWithNoRun', () {
    final editing = playing().afterDragStep(EditorAction.sound(SoundAction.setClipVolume(0.5)));
    expect(editing.history.run, EditRun.drag);
    final draft = Draft(
      project: editing.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      history: editing.history,
    );
    final back = decodeDraft(encodeDraft(draft));
    expect(back, draft);
    expect(back.history?.run, EditRun.drag);

    final history = back.history;
    expect(history, isNotNull);
    final opened = Editing.withHistory(state: EditorState(back.project), history: history!);
    expect(opened.history.run, isNull);
    expect(opened.history.past, editing.history.past);
  });
}
