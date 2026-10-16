// Undo and redo beside reduce: a history of whole projects, never of inverse actions.

import '../model/project.dart';
import '../model/text.dart';
import 'editor_action.dart';
import 'editor_state.dart';
import 'text_action.dart';

/// A row of actions on one text of one kind, or the steps of one drag, which together are one step. The Swift enum
/// EditRun, one subclass per case.
sealed class EditRun {
  const EditRun();

  const factory EditRun.typing(TextID id) = EditRunTyping;

  const factory EditRun.shaping(TextID id) = EditRunShaping;

  /// Opened only by Editing.afterDragStep, never by of.
  static const EditRun drag = EditRunDrag();

  /// The Swift of(_:on:). typing for text(setString(id, _)). shaping for text(move(id, ...)), text(turn(id, _)),
  /// and a text(setStyle(id, style)) whose style equals the stored style of id in every member but size and
  /// lineSpacing. Each only when the text id is in the project. Null for every other action.
  static EditRun? of(EditorAction action, EditorState state) {
    if (action is! EditorActionText) {
      return null;
    }
    switch (action.textAction) {
      case TextActionSetString(:final id):
        return state.project.text(id) != null ? EditRun.typing(id) : null;
      case TextActionMove(:final id) || TextActionTurn(:final id):
        return state.project.text(id) != null ? EditRun.shaping(id) : null;
      case TextActionSetStyle(:final id, :final style):
        final stored = state.project.text(id)?.style;
        if (stored == null) {
          return null;
        }
        final shaped = style.copyWith(size: stored.size, lineSpacing: stored.lineSpacing);
        return shaped == stored ? EditRun.shaping(id) : null;
      case TextActionAdd() || TextActionSelect() || TextActionTrimStart() || TextActionTrimEnd():
        return null;
    }
  }
}

final class EditRunTyping extends EditRun {
  final TextID id;

  const EditRunTyping(this.id);

  EditRunTyping copyWith({TextID? id}) => EditRunTyping(id ?? this.id);

  @override
  bool operator ==(Object other) => other is EditRunTyping && other.id == id;

  @override
  int get hashCode => Object.hash(EditRunTyping, id);
}

final class EditRunShaping extends EditRun {
  final TextID id;

  const EditRunShaping(this.id);

  EditRunShaping copyWith({TextID? id}) => EditRunShaping(id ?? this.id);

  @override
  bool operator ==(Object other) => other is EditRunShaping && other.id == id;

  @override
  int get hashCode => Object.hash(EditRunShaping, id);
}

final class EditRunDrag extends EditRun {
  const EditRunDrag();

  @override
  bool operator ==(Object other) => other is EditRunDrag;

  @override
  int get hashCode => (EditRunDrag).hashCode;
}

class UndoHistory {
  static const int depth = 50;

  /// Without blank texts, the oldest first.
  final List<Project> past;

  /// Without blank texts, the next to come back last.
  final List<Project> future;
  final EditRun? run;

  /// The Swift init(): empty, no run.
  const UndoHistory() : past = const [], future = const [], run = null;

  /// The two lists are copied into unmodifiable lists, as with Swift's value types.
  UndoHistory._({required List<Project> past, required List<Project> future, required this.run})
    : past = List<Project>.unmodifiable(past),
      future = List<Project>.unmodifiable(future);

  /// Run is wrapped in a function so that copyWith can set it to null, as Project's music.
  UndoHistory copyWith({List<Project>? past, List<Project>? future, EditRun? Function()? run}) => UndoHistory._(
    past: past ?? this.past,
    future: future ?? this.future,
    run: run != null ? run() : this.run,
  );

  @override
  bool operator ==(Object other) =>
      other is UndoHistory && _listEquals(other.past, past) && _listEquals(other.future, future) && other.run == run;

  @override
  int get hashCode => Object.hash(Object.hashAll(past), Object.hashAll(future), run);
}

bool _listEquals(List<Project> a, List<Project> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
