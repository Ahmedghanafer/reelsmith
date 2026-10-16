import '../model/words.dart';

/// The state the music part draws while a file comes in. The Swift enum MusicImport, one subclass per case.
sealed class MusicImport {
  const MusicImport();

  static const MusicImport idle = MusicImportIdle();

  static const MusicImport copying = MusicImportCopying();

  const factory MusicImport.failed(bool isProtected) = MusicImportFailed;

  /// Every key `words` can give.
  static const List<String> allWords = ['music.copying', 'music.notReadable', 'music.protected'];

  /// Null when idle.
  Words? get words => switch (this) {
    MusicImportIdle() => null,
    MusicImportCopying() => Words('music.copying'),
    MusicImportFailed(:final isProtected) => Words(isProtected ? 'music.protected' : 'music.notReadable'),
  };

  /// The five moves. Every other pair leaves the case unchanged, so a pick while copying changes nothing
  /// and a new pick is the way out of a refusal too.
  MusicImport after(MusicImportEvent event) => switch ((this, event)) {
    (MusicImportIdle() || MusicImportFailed(), MusicImportEventPicked()) => MusicImport.copying,
    (MusicImportCopying(), MusicImportEventImported()) => MusicImport.idle,
    (MusicImportCopying(), MusicImportEventRefused(:final isProtected)) => MusicImport.failed(isProtected),
    (MusicImportFailed(), MusicImportEventFailureConfirmed()) => MusicImport.idle,
    _ => this,
  };
}

final class MusicImportIdle extends MusicImport {
  const MusicImportIdle();

  @override
  bool operator ==(Object other) => other is MusicImportIdle;

  @override
  int get hashCode => (MusicImportIdle).hashCode;
}

final class MusicImportCopying extends MusicImport {
  const MusicImportCopying();

  @override
  bool operator ==(Object other) => other is MusicImportCopying;

  @override
  int get hashCode => (MusicImportCopying).hashCode;
}

final class MusicImportFailed extends MusicImport {
  final bool isProtected;

  const MusicImportFailed(this.isProtected);

  MusicImportFailed copyWith({bool? isProtected}) => MusicImportFailed(isProtected ?? this.isProtected);

  @override
  bool operator ==(Object other) => other is MusicImportFailed && other.isProtected == isProtected;

  @override
  int get hashCode => Object.hash(MusicImportFailed, isProtected);
}

/// The Swift enum MusicImport.Event, one subclass per case.
sealed class MusicImportEvent {
  const MusicImportEvent();

  /// A file or a video was chosen.
  static const MusicImportEvent picked = MusicImportEventPicked();

  /// The Engine gave its facts.
  static const MusicImportEvent imported = MusicImportEventImported();

  /// The Engine threw.
  const factory MusicImportEvent.refused(bool isProtected) = MusicImportEventRefused;

  static const MusicImportEvent failureConfirmed = MusicImportEventFailureConfirmed();
}

final class MusicImportEventPicked extends MusicImportEvent {
  const MusicImportEventPicked();

  @override
  bool operator ==(Object other) => other is MusicImportEventPicked;

  @override
  int get hashCode => (MusicImportEventPicked).hashCode;
}

final class MusicImportEventImported extends MusicImportEvent {
  const MusicImportEventImported();

  @override
  bool operator ==(Object other) => other is MusicImportEventImported;

  @override
  int get hashCode => (MusicImportEventImported).hashCode;
}

final class MusicImportEventRefused extends MusicImportEvent {
  final bool isProtected;

  const MusicImportEventRefused(this.isProtected);

  MusicImportEventRefused copyWith({bool? isProtected}) => MusicImportEventRefused(isProtected ?? this.isProtected);

  @override
  bool operator ==(Object other) => other is MusicImportEventRefused && other.isProtected == isProtected;

  @override
  int get hashCode => Object.hash(MusicImportEventRefused, isProtected);
}

final class MusicImportEventFailureConfirmed extends MusicImportEvent {
  const MusicImportEventFailureConfirmed();

  @override
  bool operator ==(Object other) => other is MusicImportEventFailureConfirmed;

  @override
  int get hashCode => (MusicImportEventFailureConfirmed).hashCode;
}
