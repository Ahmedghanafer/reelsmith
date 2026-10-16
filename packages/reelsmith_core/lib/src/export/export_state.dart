import 'dart:math';

import '../editor/editor_state.dart';
import '../model/words.dart';

/// The one value the export button and its panel draw. The Swift enum ExportState, one subclass per case.
sealed class ExportState {
  const ExportState();

  static const ExportState idle = ExportStateIdle();

  /// The percent goes from 0 to 100 and never down.
  const factory ExportState.exporting(int percent) = ExportStateExporting;

  static const ExportState saved = ExportStateSaved();

  /// `notAllowed` is true when the photo library refused the file for lack of the right to add.
  const factory ExportState.failed(bool notAllowed) = ExportStateFailed;

  /// Every key `words` can give.
  static const List<String> allWords = ['export.exporting', 'export.saved', 'export.failed', 'export.notAllowed'];

  Words? get words => switch (this) {
    ExportStateIdle() => null,
    ExportStateExporting() => Words('export.exporting'),
    ExportStateSaved() => Words('export.saved'),
    ExportStateFailed(:final notAllowed) => Words(notAllowed ? 'export.notAllowed' : 'export.failed'),
  };

  /// The progress while exporting, such as "42%", with the digits 0 to 9 in every language.
  String? get percentText => switch (this) {
    ExportStateExporting(:final percent) => '$percent%',
    _ => null,
  };

  /// Whether the phone must not lock: true while exporting, whatever the percent, and false in the three other
  /// cases.
  bool get keepsScreenAwake => this is ExportStateExporting;

  /// Whether a tap on the export button starts an export.
  bool canStart(EditorState editor) => this == ExportState.idle && editor.canExport;

  /// The moves between the cases. An event that has no meaning in a case leaves it unchanged.
  ExportState after(ExportStateEvent event) => switch ((this, event)) {
    (ExportStateIdle(), ExportStateEventStarted()) => const ExportState.exporting(0),
    // A value that is not a number is not above zero and changes nothing.
    (ExportStateExporting(:final percent), ExportStateEventProgress(:final value)) when value > 0 =>
      ExportState.exporting(max(percent, (min(value, 1.0) * 100).toInt())),
    (ExportStateExporting(), ExportStateEventSaved()) => ExportState.saved,
    (ExportStateExporting(), ExportStateEventFailed(:final notAllowed)) => ExportState.failed(notAllowed),
    (ExportStateSaved() || ExportStateFailed(), ExportStateEventClosed()) => ExportState.idle,
    _ => this,
  };
}

final class ExportStateIdle extends ExportState {
  const ExportStateIdle();

  @override
  bool operator ==(Object other) => other is ExportStateIdle;

  @override
  int get hashCode => (ExportStateIdle).hashCode;
}

final class ExportStateExporting extends ExportState {
  final int percent;

  const ExportStateExporting(this.percent);

  ExportStateExporting copyWith({int? percent}) => ExportStateExporting(percent ?? this.percent);

  @override
  bool operator ==(Object other) => other is ExportStateExporting && other.percent == percent;

  @override
  int get hashCode => Object.hash(ExportStateExporting, percent);
}

final class ExportStateSaved extends ExportState {
  const ExportStateSaved();

  @override
  bool operator ==(Object other) => other is ExportStateSaved;

  @override
  int get hashCode => (ExportStateSaved).hashCode;
}

final class ExportStateFailed extends ExportState {
  final bool notAllowed;

  const ExportStateFailed(this.notAllowed);

  ExportStateFailed copyWith({bool? notAllowed}) => ExportStateFailed(notAllowed ?? this.notAllowed);

  @override
  bool operator ==(Object other) => other is ExportStateFailed && other.notAllowed == notAllowed;

  @override
  int get hashCode => Object.hash(ExportStateFailed, notAllowed);
}

/// What happened to an export. The Swift enum ExportState.Event, one subclass per case.
sealed class ExportStateEvent {
  const ExportStateEvent();

  /// She tapped the export button.
  static const ExportStateEvent started = ExportStateEventStarted();

  /// The Engine reported progress, from 0 to 1.
  const factory ExportStateEvent.progress(double value) = ExportStateEventProgress;

  /// The file is in the photo library.
  static const ExportStateEvent saved = ExportStateEventSaved();

  const factory ExportStateEvent.failed(bool notAllowed) = ExportStateEventFailed;

  /// She closed the saved or the failed panel.
  static const ExportStateEvent closed = ExportStateEventClosed();
}

final class ExportStateEventStarted extends ExportStateEvent {
  const ExportStateEventStarted();

  @override
  bool operator ==(Object other) => other is ExportStateEventStarted;

  @override
  int get hashCode => (ExportStateEventStarted).hashCode;
}

final class ExportStateEventProgress extends ExportStateEvent {
  final double value;

  const ExportStateEventProgress(this.value);

  ExportStateEventProgress copyWith({double? value}) => ExportStateEventProgress(value ?? this.value);

  @override
  bool operator ==(Object other) => other is ExportStateEventProgress && other.value == value;

  @override
  int get hashCode => Object.hash(ExportStateEventProgress, value);
}

final class ExportStateEventSaved extends ExportStateEvent {
  const ExportStateEventSaved();

  @override
  bool operator ==(Object other) => other is ExportStateEventSaved;

  @override
  int get hashCode => (ExportStateEventSaved).hashCode;
}

final class ExportStateEventFailed extends ExportStateEvent {
  final bool notAllowed;

  const ExportStateEventFailed(this.notAllowed);

  ExportStateEventFailed copyWith({bool? notAllowed}) => ExportStateEventFailed(notAllowed ?? this.notAllowed);

  @override
  bool operator ==(Object other) => other is ExportStateEventFailed && other.notAllowed == notAllowed;

  @override
  int get hashCode => Object.hash(ExportStateEventFailed, notAllowed);
}

final class ExportStateEventClosed extends ExportStateEvent {
  const ExportStateEventClosed();

  @override
  bool operator ==(Object other) => other is ExportStateEventClosed;

  @override
  int get hashCode => (ExportStateEventClosed).hashCode;
}
