import '../editor/editor_action.dart';
import '../editor/editor_state.dart';
import '../editor/reduce.dart';
import '../model/media.dart';
import '../model/project.dart';
import '../model/words.dart';

/// The one value the start screen draws. The Swift enum StartState, one subclass per case.
sealed class StartState {
  const StartState();

  static const StartState idle = StartStateIdle();

  static const StartState copying = StartStateCopying();

  static const StartState failed = StartStateFailed();

  /// Carries the project to open.
  const factory StartState.ready(Project project) = StartStateReady;

  /// Every key `words` can give.
  static const List<String> allWords = ['start.copying', 'start.noneReadable'];

  Words? get words => switch (this) {
    StartStateIdle() || StartStateReady() => null,
    StartStateCopying() => Words('start.copying'),
    StartStateFailed() => Words('start.noneReadable'),
  };

  /// The moves between the cases. An event that has no meaning in a case leaves it unchanged.
  StartState after(StartStateEvent event) {
    switch ((this, event)) {
      case (StartStateIdle(), StartStateEventPickerClosed(:final chosen)):
        return chosen > 0 ? StartState.copying : StartState.idle;
      case (StartStateCopying(), StartStateEventCopyingEnded(:final facts)):
        final project = reduce(const EditorState(Project()), EditorAction.addClips(facts)).project;
        return project.clips.isEmpty ? StartState.failed : StartState.ready(project);
      case (StartStateFailed(), StartStateEventFailureConfirmed()):
        return StartState.idle;
      default:
        return this;
    }
  }
}

final class StartStateIdle extends StartState {
  const StartStateIdle();

  @override
  bool operator ==(Object other) => other is StartStateIdle;

  @override
  int get hashCode => (StartStateIdle).hashCode;
}

final class StartStateCopying extends StartState {
  const StartStateCopying();

  @override
  bool operator ==(Object other) => other is StartStateCopying;

  @override
  int get hashCode => (StartStateCopying).hashCode;
}

final class StartStateFailed extends StartState {
  const StartStateFailed();

  @override
  bool operator ==(Object other) => other is StartStateFailed;

  @override
  int get hashCode => (StartStateFailed).hashCode;
}

final class StartStateReady extends StartState {
  final Project project;

  const StartStateReady(this.project);

  StartStateReady copyWith({Project? project}) => StartStateReady(project ?? this.project);

  @override
  bool operator ==(Object other) => other is StartStateReady && other.project == project;

  @override
  int get hashCode => Object.hash(StartStateReady, project);
}

/// What happened on the start screen. The Swift enum StartState.Event, one subclass per case.
sealed class StartStateEvent {
  const StartStateEvent();

  /// The picker closed with this many videos chosen.
  const factory StartStateEvent.pickerClosed(int chosen) = StartStateEventPickerClosed;

  /// Copying ended. These are the facts that could be read, in the order chosen.
  factory StartStateEvent.copyingEnded(List<MediaInfo> facts) = StartStateEventCopyingEnded;

  /// She confirmed that none of the videos could be read.
  static const StartStateEvent failureConfirmed = StartStateEventFailureConfirmed();
}

final class StartStateEventPickerClosed extends StartStateEvent {
  final int chosen;

  const StartStateEventPickerClosed(this.chosen);

  StartStateEventPickerClosed copyWith({int? chosen}) => StartStateEventPickerClosed(chosen ?? this.chosen);

  @override
  bool operator ==(Object other) => other is StartStateEventPickerClosed && other.chosen == chosen;

  @override
  int get hashCode => Object.hash(StartStateEventPickerClosed, chosen);
}

final class StartStateEventCopyingEnded extends StartStateEvent {
  final List<MediaInfo> facts;

  /// The facts are copied into an unmodifiable list, as with Swift's value types.
  StartStateEventCopyingEnded(List<MediaInfo> facts) : facts = List<MediaInfo>.unmodifiable(facts);

  StartStateEventCopyingEnded copyWith({List<MediaInfo>? facts}) => StartStateEventCopyingEnded(facts ?? this.facts);

  @override
  bool operator ==(Object other) {
    if (other is! StartStateEventCopyingEnded || other.facts.length != facts.length) {
      return false;
    }
    for (var index = 0; index < facts.length; index++) {
      if (other.facts[index] != facts[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(StartStateEventCopyingEnded, Object.hashAll(facts));
}

final class StartStateEventFailureConfirmed extends StartStateEvent {
  const StartStateEventFailureConfirmed();

  @override
  bool operator ==(Object other) => other is StartStateEventFailureConfirmed;

  @override
  int get hashCode => (StartStateEventFailureConfirmed).hashCode;
}
