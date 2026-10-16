import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../engine/video_engine.dart';

/// The one object screens draw from and send actions to. It holds the `Editing` of Core: the state every
/// screen reads, and the history that undo and redo step through. With an open draft it writes the project
/// there after a change that ends no run, with the export choice and the undo history, synchronously.
///
/// It keeps the preview player of Swift in step: from its making it listens to the events `playhead` and
/// `playedToEnd`, makes the preview, and then calls `show` at every change of the project or of playing,
/// with the playhead whenever Dart moved it. A playhead the player reported is never sent back as it comes:
/// only a pause sends the store's playhead, so the player shows the time the store kept. Whoever made the
/// store disposes it once it is closed, which lets the preview go.
///
/// https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html
/// https://api.dart.dev/stable/dart-async/Stream/listen.html
/// https://api.dart.dev/stable/dart-core/DateTime/DateTime.now.html
class EditorStore extends ChangeNotifier {
  /// `history` is the undo history the draft was written with. Null reads as an empty history.
  EditorStore({
    required core.EditorState state,
    required this.mediaFolder,
    required this.options,
    required this.engine,
    this.draft,
    core.ExportSettings exportSettings = core.ExportSettings.startChoice,
    core.UndoHistory? history,
  }) : _editing = core.Editing.withHistory(state: state, history: history ?? const core.UndoHistory()),
       _exportSettings = exportSettings {
    _playheads = engine.playhead.listen(_reported);
    _ends = engine.playedToEnd.listen((_) => _playedToEnd());
    // Before the preview is made, so the count of its first build is never missed.
    _buildCounts = engine.buildCount.listen((count) {
      _builds = count;
      notifyListeners();
    });
    engine.createPreview().then(
      (id) {
        if (_disposed) {
          _disposePreview(id);
          return;
        }
        _textureId = id;
        notifyListeners();
        _show(withPlayhead: true);
      },
      onError: (Object error) {
        print('editor: the preview was not made: $error');
      },
    );
  }

  core.Editing _editing;
  core.Editing get editing => _editing;
  core.EditorState get state => _editing.state;
  final Directory mediaFolder;

  /// The values `launch` gave, as one JSON object.
  final Map<String, Object?> options;

  /// Null for a seeded start without -drafts.
  final core.OpenDraft? draft;
  core.ExportSettings _exportSettings;
  core.ExportSettings get exportSettings => _exportSettings;
  final VideoEngine engine;

  /// The texture of the preview, null until `createPreview` gave it.
  int? get textureId => _textureId;
  int? _textureId;
  late final StreamSubscription<int> _playheads;
  late final StreamSubscription<void> _ends;
  late final StreamSubscription<int> _buildCounts;

  /// The last `buildCount` the engine sent, 0 until the first.
  int get builds => _builds;
  int _builds = 0;
  bool _disposed = false;

  void send(core.EditorAction action) {
    _change(_editing.after(action));
    if (_editing.writesNow) {
      write();
    }
  }

  void undo() {
    _change(_editing.undone());
    if (_editing.writesNow) {
      write();
    }
  }

  void redo() {
    _change(_editing.redone());
    if (_editing.writesNow) {
      write();
    }
  }

  /// One step of a drag: with the steps before it in the same run one undo step. It writes nothing.
  void sendDragStep(core.EditorAction action) {
    _change(_editing.afterDragStep(action));
  }

  /// The end of a drag: the run ends, and the draft is written when something is not written yet.
  void endDrag() {
    _change(_editing.endingRun());
    if (_editing.writesNow) {
      write();
    }
  }

  /// Writes the project without its blank texts, the export choice, the time and the history to the draft,
  /// whatever `unsaved` says. A throw is logged and leaves `unsaved` as it was, so the next write tries again.
  void write() {
    final draft = this.draft;
    if (draft == null) {
      return;
    }
    final stored = core.Draft(
      project: _editing.state.project.withoutBlankTexts,
      exportSettings: _exportSettings,
      changed: DateTime.now(),
      history: _editing.history,
    );
    try {
      draft.write(stored);
      _editing = _editing.written();
      notifyListeners();
    } catch (error) {
      print('editor: the draft was not written: $error');
    }
  }

  /// Writes when something is not written yet, whatever the run.
  void writeNow() {
    if (_editing.unsaved) {
      write();
    }
  }

  bool _isOpen = true;

  /// True when made. The root shows the start screen once it is false.
  bool get isOpen => _isOpen;
  bool _closing = false;

  /// Writes the cover of the project to the draft's cover file when the project has a clip, else removes
  /// that file. With no draft it does nothing. A throw is logged and leaves the file as it was.
  Future<void> makeCover() async {
    final draft = this.draft;
    if (draft == null) {
      return;
    }
    final project = _editing.state.project;
    if (project.clips.isEmpty) {
      final cover = draft.coverFile;
      if (cover.existsSync()) {
        try {
          cover.deleteSync();
        } catch (error) {
          print('editor: the cover was not removed: $error');
        }
      }
      return;
    }
    try {
      await engine.writeCover(_projectJson(project), mediaFolder.path, draft.coverFile.path);
    } catch (error) {
      print('editor: the cover was not written: $error');
    }
  }

  /// Writes what is not written yet, makes the cover, then closes. A second call while one runs does nothing.
  Future<void> close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    writeNow();
    await makeCover();
    _isOpen = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Takes the next editing and shows it to the player when the project or playing changed, or when the
  /// playhead changed and `reported` is false. The playhead goes with it when this moved it, and on a pause.
  void _change(core.Editing next, {bool reported = false}) {
    final before = _editing.state;
    _editing = next;
    final after = next.state;
    final moved = !reported && after.playhead != before.playhead;
    final paused = before.isPlaying && !after.isPlaying;
    if (moved || paused || after.project != before.project || after.isPlaying != before.isPlaying) {
      _show(withPlayhead: moved || paused);
    }
    notifyListeners();
  }

  /// The time the player reported while playing. Once the store has stopped playing it is dropped.
  void _reported(int ticks) {
    if (!state.isPlaying) {
      return;
    }
    _change(_editing.after(core.EditorAction.movePlayhead(core.Time(ticks: ticks))), reported: true);
    if (_editing.writesNow) {
      write();
    }
  }

  /// The player played to its end: the playhead goes to the end and the store pauses there. Once the store
  /// has stopped playing it is dropped.
  void _playedToEnd() {
    if (!state.isPlaying) {
      return;
    }
    _change(_editing.after(core.EditorAction.movePlayhead(state.project.duration)), reported: true);
    send(core.EditorAction.pause);
  }

  void _show({required bool withPlayhead}) {
    final id = _textureId;
    if (id == null) {
      return;
    }
    final now = state;
    final String project;
    try {
      project = _projectJson(now.project);
    } catch (error) {
      print('editor: the preview was not shown: $error');
      return;
    }
    engine
        .show(id, project, mediaFolder.path, withPlayhead ? now.playhead.ticks : null, now.isPlaying)
        .catchError((Object error) {
          print('editor: the preview was not shown: $error');
        });
  }

  void _disposePreview(int id) {
    engine.disposePreview(id).catchError((Object error) {
      print('editor: the preview was not let go: $error');
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _playheads.cancel();
    _ends.cancel();
    _buildCounts.cancel();
    final id = _textureId;
    if (id != null) {
      _disposePreview(id);
    }
    super.dispose();
  }

  // slot: leave
  // end slot: leave

  // slot: export-choice
  /// Sets the export choice and writes the draft with it. The choice is no part of the history, so nothing
  /// is left unsaved and `writeNow` would write nothing.
  void choose(core.ExportSettings settings) {
    _exportSettings = settings;
    notifyListeners();
    write();
  }
  // end slot: export-choice

  // slot: fold
  /// The blocks of the strip are thin and show no frames. False when an editor opens, toggled by `editor.frames`,
  /// with no undo step, and never stored.
  bool get framesFolded => _framesFolded;
  bool _framesFolded = false;
  set framesFolded(bool folded) {
    _framesFolded = folded;
    notifyListeners();
  }
  // end slot: fold

  // slot: guide
  // end slot: guide
}

/// The shelf of drafts on the folder `launch` gives: `testDraftsFolder` (`<caches>/TestDrafts`) when the launch
/// names `drafts`, as a seeded start with -drafts does, else `draftsFolder` (`<Application Support>/Drafts`), as
/// `LaunchOptions.draftsFolder` chooses in Swift.
core.DraftShelf draftShelf(Map<String, Object?> options) {
  final folder = options['drafts'] == null ? options['draftsFolder'] : options['testDraftsFolder'];
  return core.DraftShelf(Directory(folder! as String));
}

/// The project as the `project` member of the draft JSON, the form a project crosses to Swift in.
String _projectJson(core.Project project) {
  final draft = core.Draft(project: project, exportSettings: core.ExportSettings.startChoice, changed: DateTime.now());
  final json = jsonDecode(utf8.decode(core.encodeDraft(draft))) as Map<String, Object?>;
  return jsonEncode(json['project']);
}
