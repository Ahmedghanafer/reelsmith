import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../engine/video_engine.dart';
import '../../words/words.dart';
import '../editor_store.dart';
import 'export_panel.dart';
import 'export_settings_sheet.dart';

/// The export row: the choice of size and rate, then the export button and the panel it puts over the editor.
/// It decides nothing: `ExportState` says whether the button is enabled and what the panel shows, and only
/// `ExportState.after` moves it. The choice is the store's, which keeps it with the draft, and the sheet of the
/// choice gives the settings it is given back to the store. The two buttons take an equal share of the row, so the
/// export button stands still whatever the label of the choice says. The row lays out from leading to trailing,
/// so Arabic mirrors it.
///
/// The panel is a full screen route over the editor, so nothing of the editor behind it answers a touch. The
/// screen stays awake while the state says so: `keepAwake` goes to Swift at every change of
/// `ExportState.keepsScreenAwake`, true at the start and false at every ending.
///
/// https://api.flutter.dev/flutter/material/MaterialPageRoute-class.html
/// https://api.flutter.dev/flutter/material/PageRoute/fullscreenDialog.html
/// https://api.flutter.dev/flutter/material/showModalBottomSheet.html
/// https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html
/// https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class ExportButton extends StatefulWidget {
  const ExportButton({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  final ValueNotifier<core.ExportState> _state = ValueNotifier(core.ExportState.idle);

  /// What the written file holds, null when no file was written or it could not be read.
  String? _facts;
  Route<void>? _panel;

  EditorStore get store => widget.store;

  /// A seeded start or a launch with -drafts shows what the file holds, "none" when it cannot be read.
  bool get _showsInfo => store.options['seed'] != null || store.options['drafts'] != null;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(child: _choice(context)),
        Expanded(
          child: ValueListenableBuilder<core.ExportState>(
            valueListenable: _state,
            builder: (context, state, _) {
              final enabled = state.canStart(store.state);
              return _button('editor.export', widget.words.text(const core.Words('export.button')), enabled ? _start : null);
            },
          ),
        ),
      ],
    );
  }

  /// The words of the chosen size and rate, side by side from the leading end, so Arabic reads the size first.
  /// A tap shows the sheet of the choice.
  Widget _choice(BuildContext context) {
    final settings = store.exportSettings;
    final size = widget.words.text(settings.size.words);
    final rate = widget.words.text(settings.rate.words);
    return Semantics(
      identifier: 'editor.exportSettings',
      container: true,
      button: true,
      enabled: true,
      label: '$size $rate',
      onTap: () => _choose(context),
      excludeSemantics: true,
      child: TextButton(
        onPressed: () => _choose(context),
        style: _style,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: [
            Flexible(child: Text(size, maxLines: 1, softWrap: false)),
            Flexible(child: Text(rate, maxLines: 1, softWrap: false)),
          ],
        ),
      ),
    );
  }

  void _choose(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => ListenableBuilder(
        listenable: store,
        builder: (_, _) => ExportSettingsSheet(
          settings: store.exportSettings,
          words: widget.words,
          choose: store.choose,
          done: () => Navigator.of(sheet).pop(),
        ),
      ),
    );
  }

  static final ButtonStyle _style = TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 44),
    textStyle: const TextStyle(fontSize: 17),
  );

  Widget _button(String identifier, String label, VoidCallback? tap) {
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      enabled: tap != null,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: TextButton(
        onPressed: tap,
        style: _style,
        child: Text(label, maxLines: 1, softWrap: false),
      ),
    );
  }

  /// Exports the project as it is at the tap, at the choice shown, then adds the written file to Photos. There
  /// is no cancel: the export runs to its end. A thrown export or save ends failed, and saves nothing.
  Future<void> _start() async {
    if (!_state.value.canStart(store.state)) {
      return;
    }
    store.send(core.EditorAction.pause);
    _move(core.ExportStateEvent.started);
    final (:project, :settings) = _exportJson(store.state.project, store.exportSettings);
    final engine = store.engine;
    final progress = engine.exportProgress.listen((value) => _move(core.ExportStateEvent.progress(value)));
    String? facts;
    core.ExportStateEvent end;
    try {
      final exported = await engine.export(project, settings, store.mediaFolder.path, store.options['exportFails'] == true);
      facts = exported.facts;
      end = switch (await engine.saveToPhotos(exported.file)) {
        SaveOutcome.saved => core.ExportStateEvent.saved,
        SaveOutcome.notAllowed => const core.ExportStateEvent.failed(true),
        SaveOutcome.failed => const core.ExportStateEvent.failed(false),
      };
    } catch (error) {
      print('export: the export failed: $error');
      end = const core.ExportStateEvent.failed(false);
    }
    await progress.cancel();
    _facts = facts;
    _move(end);
  }

  /// Moves the state by the event: tells Swift when the screen must stay awake or may lock again, puts the panel
  /// over the editor at the start and takes it away when it is closed.
  void _move(core.ExportStateEvent event) {
    final before = _state.value;
    final after = before.after(event);
    if (after == before) {
      return;
    }
    if (after.keepsScreenAwake != before.keepsScreenAwake) {
      store.engine.keepAwake(after.keepsScreenAwake).catchError((Object error) {
        print('export: the screen awake was not set: $error');
      });
    }
    if (!mounted) {
      return;
    }
    _state.value = after;
    if (before == core.ExportState.idle) {
      final panel = MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ValueListenableBuilder<core.ExportState>(
          valueListenable: _state,
          builder: (_, state, _) => ExportPanel(
            state: state,
            words: widget.words,
            fileInfo: _showsInfo ? (_facts ?? 'none') : null,
            close: () => _move(core.ExportStateEvent.closed),
          ),
        ),
      );
      _panel = panel;
      Navigator.of(context).push(panel);
    } else if (after == core.ExportState.idle) {
      final panel = _panel;
      _panel = null;
      if (panel != null && panel.isCurrent) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// The project and the choice as they cross to Swift for an export: the members `project` and `exportSettings`
/// of the draft JSON.
({String project, String settings}) _exportJson(core.Project project, core.ExportSettings settings) {
  final draft = core.Draft(project: project, exportSettings: settings, changed: DateTime.now());
  final json = jsonDecode(utf8.decode(core.encodeDraft(draft))) as Map<String, Object?>;
  return (project: jsonEncode(json['project']), settings: jsonEncode(json['exportSettings']));
}
