import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

/// Every sequence of four actions from a fixed menu, walked in order. Nothing is drawn at random.
void main() {
  final menu = <EditorAction>[
    EditorAction.select(const ClipID(1)),
    EditorAction.deleteSelected,
    EditorAction.trimEnd(const ClipID(1), const Time(ticks: 300)),
    EditorAction.movePlayhead(const Time(ticks: 900)),
    EditorAction.split,
    EditorAction.text(TextAction.setString(const TextID(1), 'A')),
    EditorAction.text(TextAction.setString(const TextID(1), 'AB')),
    EditorAction.text(TextAction.move(const TextID(1), 100, 100)),
    EditorAction.text(TextAction.add),
    EditorAction.sound(SoundAction.setClipVolume(0.5)),
    EditorAction.sound(SoundAction.muteClips(true)),
    EditorAction.pause,
  ];

  /// Equal with nextTextID left out, as one step compares two projects.
  bool sameStep(Project a, Project b) => a.copyWith(nextTextID: b.nextTextID) == b;

  test('testEverySequenceOfFourIsUndoneAndRedoneWhole', () {
    final began = Stopwatch()..start();
    final first = Editing(
      EditorState(
        Seed.textWide.project,
      ).copyWith(selectedText: () => Seed.textWide.selectedText, showsSound: Seed.textWide.showsSound),
    );
    final startProject = first.state.project.withoutBlankTexts;
    var count = 0;
    final failures = <String>[];
    for (final a in menu) {
      for (final b in menu) {
        for (final c in menu) {
          for (final d in menu) {
            final sequence = [a, b, c, d];
            var editing = first;
            for (final action in sequence) {
              editing = editing.after(action);
            }
            final end = editing.state.project.withoutBlankTexts;
            var undone = editing;
            while (undone.canUndo) {
              undone = undone.undone();
            }
            var redone = undone;
            while (redone.canRedo) {
              redone = redone.redone();
            }
            count += 1;
            final backAtStart = sameStep(undone.state.project.withoutBlankTexts, startProject);
            final backAtEnd = redone.state.project.withoutBlankTexts == end;
            if (!(backAtStart && backAtEnd)) {
              failures.add(
                'sequence ${sequence.map(menu.indexOf).toList()}: undone to the start $backAtStart, '
                'redone to the end $backAtEnd',
              );
            }
          }
        }
      }
    }
    print(
      'Undo guard: $count sequences of four in ${began.elapsedMilliseconds / 1000} seconds, '
      '${failures.length} failed',
    );
    expect(failures.take(5).toList(), <String>[]);
    expect(count, 20736);
  });
}
