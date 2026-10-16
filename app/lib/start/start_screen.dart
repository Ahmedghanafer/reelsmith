import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor/editor_store.dart';
import '../engine/video_engine.dart';
import '../words/words.dart';

/// The start screen: the title, the choice of the shape, and "New project", which opens the system picker for
/// videos and photos.
/// It draws a `StartState`, which only `StartState.after` moves. Its own state is the chosen shape and the
/// summaries of the drafts on the shelf, read when it is made. `open` gets the store the editor opens with.
/// A new project is a new draft: made first, what she picked copied into its media folder, then written.
/// The root makes the screen anew each time the editor closes, so the shape is the start choice again and
/// the drafts are read again.
///
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/widgets/Row-class.html
class StartScreen extends StatefulWidget {
  const StartScreen({
    super.key,
    required this.engine,
    required this.options,
    required this.shelf,
    required this.words,
    required this.open,
  });

  final VideoEngine engine;

  /// The values `launch` gave.
  final Map<String, Object?> options;
  final core.DraftShelf shelf;
  final WordsText words;
  final void Function(EditorStore store) open;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

const Color _accent = Color(0xFF0A84FF);

class _StartScreenState extends State<StartScreen> {
  core.StartState _state = core.StartState.idle;
  core.Canvas _canvas = core.Canvas.startChoice;
  List<core.DraftSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _summaries = widget.shelf.list();
  }

  String _text(core.Words words) => widget.words.text(words);

  @override
  Widget build(BuildContext context) {
    final idle = _state == core.StartState.idle;
    final words = _state.words;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  identifier: 'start.title',
                  container: true,
                  child: Text(_text(core.Words('start.title')), style: const TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 24),
                // A row, so the leading shape is first and Arabic changes the sides by itself.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final shape in core.Canvas.allCases) ...[
                      if (shape != core.Canvas.allCases.first) const SizedBox(width: 12),
                      _shape(shape),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Semantics(
                  identifier: 'start.newProject',
                  container: true,
                  button: true,
                  enabled: idle,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: idle ? _newProject : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: idle ? _accent : Theme.of(context).disabledColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        _text(core.Words('start.newProject')),
                        style: const TextStyle(fontSize: 17, color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ),
                if (words != null) ...[
                  const SizedBox(height: 24),
                  Text(_text(words), textAlign: TextAlign.center),
                ],
                if (_state == core.StartState.failed) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    identifier: 'start.ok',
                    container: true,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _state = _state.after(core.StartStateEvent.failureConfirmed)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _text(core.Words('start.ok')),
                          style: const TextStyle(fontSize: 17, color: _accent),
                        ),
                      ),
                    ),
                  ),
                ],
                // slot: drafts
                // end slot: drafts
                if (widget.options['drafts'] != null) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    identifier: 'start.draftsInfo',
                    container: true,
                    child: Text(core.draftsInfo(_summaries), style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One shape: its words in a rounded box, filled when chosen. The whole box takes the tap, the padding of
  /// the one with no fill too.
  Widget _shape(core.Canvas shape) {
    final chosen = shape == _canvas;
    return Semantics(
      identifier: shape.words.key,
      container: true,
      button: true,
      selected: chosen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _canvas = shape),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: chosen ? _accent : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Text(
            _text(shape.words),
            style: TextStyle(
              fontSize: 17,
              color: chosen ? const Color(0xFFFFFFFF) : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  void _show(core.StartState state) {
    if (mounted) {
      setState(() => _state = state);
    } else {
      _state = state;
    }
  }

  /// Shows the picker, then makes the draft, copies what she picked into it and opens the editor on it. A
  /// picker closed with nothing chosen leaves the screen as it was. A draft that cannot be made, or a copy
  /// that gives nothing readable, shows the failed state and leaves no draft.
  Future<void> _newProject() async {
    int chosen;
    try {
      chosen = await widget.engine.pick(true, 0);
    } catch (error) {
      print('start: the picker was not shown: $error');
      chosen = 0;
    }
    _show(_state.after(core.StartStateEvent.pickerClosed(chosen)));
    if (_state != core.StartState.copying) {
      return;
    }
    final core.OpenDraft draft;
    try {
      draft = widget.shelf.create(
        core.Draft(
          project: core.Project(canvas: _canvas),
          exportSettings: core.ExportSettings.startChoice,
          changed: DateTime.now(),
        ),
      );
    } catch (_) {
      // The shelf leaves no draft when it throws.
      _show(_state.after(core.StartStateEvent.copyingEnded(const [])));
      return;
    }
    List<String> facts;
    try {
      facts = await widget.engine.copyPicked(draft.mediaFolder.path);
    } catch (error) {
      print('start: the picked items were not copied: $error');
      facts = const [];
    }
    _show(_state.after(core.StartStateEvent.copyingEnded(facts.map(_mediaInfo).nonNulls.toList())));
    final state = _state;
    if (state is core.StartStateReady) {
      final project = state.project.copyWith(canvas: _canvas);
      try {
        draft.write(
          core.Draft(project: project, exportSettings: core.ExportSettings.startChoice, changed: DateTime.now()),
        );
      } catch (error) {
        print('start: the new draft was not written: $error');
      }
      widget.open(
        EditorStore(
          state: core.EditorState(project),
          mediaFolder: draft.mediaFolder,
          options: widget.options,
          engine: widget.engine,
          draft: draft,
        ),
      );
    } else if (state == core.StartState.failed) {
      try {
        widget.shelf.delete(draft.id);
      } catch (_) {}
    }
  }
}

/// A media fact as `copyPicked` gives it: the JSON the Swift encoder writes of `MediaInfo`, kind video when
/// it is missing. A fact that cannot be read is logged and left out.
core.MediaInfo? _mediaInfo(String text) {
  try {
    final json = jsonDecode(text) as Map<String, Object?>;
    final kind = json['kind'] as String?;
    return core.MediaInfo(
      id: core.MediaID((json['id']! as Map<String, Object?>)['raw']! as String),
      fileName: json['fileName']! as String,
      width: (json['width']! as num).toInt(),
      height: (json['height']! as num).toInt(),
      duration: core.Time(ticks: ((json['duration']! as Map<String, Object?>)['ticks']! as num).toInt()),
      quarterTurns: (json['quarterTurns']! as num).toInt(),
      hasSound: json['hasSound']! as bool,
      kind: kind == null ? core.MediaKind.video : core.MediaKind.values.firstWhere((value) => value.rawValue == kind),
    );
  } catch (error) {
    print('start: a media fact was not read: $error');
    return null;
  }
}
