// Undo and redo beside reduce: a history of whole projects, never of inverse actions.

import '../model/project.dart';
import '../model/text.dart';
import '../model/time.dart';
import 'editor_action.dart';
import 'editor_state.dart';
import 'reduce.dart';
import 'text_action.dart';

extension ProjectWithoutBlankTexts on Project {
  /// Every text that isBlank taken out, all else kept.
  Project get withoutBlankTexts => copyWith(texts: texts.where((text) => !text.isBlank).toList());
}

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

  bool get canUndo => past.isNotEmpty;

  bool get canRedo => future.isNotEmpty;

  /// A new step: the project before it goes to the end of past, the oldest dropped past depth, no future.
  UndoHistory add(Project before, {required EditRun? run}) {
    final steps = [...past, before];
    return UndoHistory._(
      past: steps.length > depth ? steps.sublist(steps.length - depth) : steps,
      future: const [],
      run: run,
    );
  }

  UndoHistory endRun() => copyWith(run: () => null);

  /// The last of past taken out, all else kept.
  UndoHistory dropLastStep() => past.isEmpty ? this : copyWith(past: past.sublist(0, past.length - 1));

  /// The Swift undo(from:): the last of past, with the history that has the current project put at the end of
  /// future and no run. Null when past is empty.
  ({UndoHistory history, Project project})? undo(Project current) {
    if (past.isEmpty) {
      return null;
    }
    return (
      history: UndoHistory._(past: past.sublist(0, past.length - 1), future: [...future, current], run: null),
      project: past.last,
    );
  }

  /// The Swift redo(from:): the last of future, with the history that has the current project put at the end of
  /// past and no run. Null when future is empty.
  ({UndoHistory history, Project project})? redo(Project current) {
    if (future.isEmpty) {
      return null;
    }
    return (
      history: UndoHistory._(past: [...past, current], future: future.sublist(0, future.length - 1), run: null),
      project: future.last,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UndoHistory && _listEquals(other.past, past) && _listEquals(other.future, future) && other.run == run;

  @override
  int get hashCode => Object.hash(Object.hashAll(past), Object.hashAll(future), run);
}

class Editing {
  final EditorState state;
  final UndoHistory history;
  final bool unsaved;

  /// The Swift init(state:): the state as given, an empty history, unsaved false.
  const Editing(this.state) : history = const UndoHistory(), unsaved = false;

  /// The Swift init(state:history:): the state as given, that history with its run ended, unsaved false.
  Editing.withHistory({required this.state, required UndoHistory history})
    : history = history.endRun(),
      unsaved = false;

  const Editing._({required this.state, required this.history, required this.unsaved});

  Editing after(EditorAction action) => _stepped(action, EditRun.of(action, state));

  /// As after, with the run drag: the steps of one drag that change the project are one step.
  Editing afterDragStep(EditorAction action) => _stepped(action, EditRun.drag);

  /// Run null, all else kept. A drag run that ends on the project it began with leaves no step: its step is taken
  /// out of past, so an undo after it is not one that changes nothing. The future it cleared stays cleared.
  Editing endingRun() {
    var next = history;
    final began = history.past.isEmpty ? null : history.past.last;
    if (history.run == EditRun.drag && began == state.project.withoutBlankTexts) {
      next = next.dropLastStep();
    }
    return copyWith(history: next.endRun());
  }

  /// An action that changes nothing ends a run of another kind, but never a drag run: the player reports its
  /// time while playing with such an action every frame.
  Editing _stepped(EditorAction action, EditRun? k) {
    final nextState = reduce(state, action);
    final b = state.project.withoutBlankTexts;
    final a = nextState.project.withoutBlankTexts;
    if (!_oneStepApart(a, b)) {
      if (k != history.run && history.run != EditRun.drag) {
        return copyWith(state: nextState, history: history.endRun());
      }
      return copyWith(state: nextState);
    }
    if (k != null && k == history.run) {
      return copyWith(state: nextState, unsaved: true);
    }
    return copyWith(state: nextState, history: history.add(b, run: k), unsaved: true);
  }

  /// This when canUndo is false.
  Editing undone() {
    final back = history.undo(state.project.withoutBlankTexts);
    if (back == null) {
      return this;
    }
    return _restore(back.project, back.history);
  }

  /// This when canRedo is false.
  Editing redone() {
    final back = history.redo(state.project.withoutBlankTexts);
    if (back == null) {
      return this;
    }
    return _restore(back.project, back.history);
  }

  bool get canUndo => history.canUndo;

  bool get canRedo => history.canRedo;

  /// unsaved, and history.run is null.
  bool get writesNow => unsaved && history.run == null;

  /// unsaved false, all else as it was.
  Editing written() => copyWith(unsaved: false);

  /// The project back from the history, with what the state holds outside it kept only where it still fits.
  Editing _restore(Project project, UndoHistory history) {
    final selection = state.selection;
    final selectedText = state.selectedText;
    final restored = state.copyWith(
      project: project,
      selection: selection != null && project.positionOfClip(selection) == null ? () => null : null,
      selectedText: selectedText != null && project.text(selectedText) == null ? () => null : null,
      playhead: _min(state.playhead, project.duration).roundedDownToFrame,
      isPlaying: false,
      showsSound: project.clips.isEmpty ? false : null,
    );
    return Editing._(state: restored, history: history, unsaved: true);
  }

  Editing copyWith({EditorState? state, UndoHistory? history, bool? unsaved}) => Editing._(
    state: state ?? this.state,
    history: history ?? this.history,
    unsaved: unsaved ?? this.unsaved,
  );

  @override
  bool operator ==(Object other) =>
      other is Editing && other.state == state && other.history == history && other.unsaved == unsaved;

  @override
  int get hashCode => Object.hash(state, history, unsaved);
}

/// Two projects without their blank texts are one step apart when they differ in a member other than nextTextID.
bool _oneStepApart(Project a, Project b) => a.copyWith(nextTextID: b.nextTextID) != b;

/// Swift's min: the first when the two are equal.
Time _min(Time a, Time b) => b < a ? b : a;

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
