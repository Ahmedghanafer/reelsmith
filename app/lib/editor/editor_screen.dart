import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../words/words.dart';
import 'editor_store.dart';
import 'export/export_button.dart';
import 'preview/preview_pane.dart';
import 'strip/strip.dart';
import 'text/text_panel.dart';
import 'tools/tools_row.dart';

/// The editor shell, in the colours of the theme, light or dark as the system is: four regions from top to bottom, each with the slot of the story that fills it, and between
/// the tools and the export the text region, only while a text is selected, the sound region, only while the sound
/// panel shows, or the clip region, only while a clip is selected. Core keeps any two of them from showing
/// together. The root and the regions are semantics containers, so a region is found while it is empty and a
/// control inside it keeps its own identifier. The regions follow the direction of the language: what stays left to
/// right fixes that itself.
///
/// On a test start (a seed or `-drafts`) four info lines stand above the regions. On a seeded start the value of
/// `editor.picture` is the last `buildCount` the engine sent, 0 until the first.
///
/// The draft is written when the app leaves the active phase, a run that is still open included, and its cover is
/// made then too. A tap on the button to the projects closes the store, which writes and makes the cover first.
///
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
/// https://api.flutter.dev/flutter/widgets/ListenableBuilder-class.html
/// https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html
/// https://api.flutter.dev/flutter/widgets/SafeArea-class.html
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final StreamSubscription<int> _builds;
  late final AppLifecycleListener _lifecycle;
  int _built = 0;
  String _faceNames = '';

  EditorStore get store => widget.store;

  bool get _showsInfo => store.options['seed'] != null || store.options['drafts'] != null;

  @override
  void initState() {
    super.initState();
    _builds = store.engine.buildCount.listen((count) => setState(() => _built = count));
    // Once a leave: on the way out and back the phases inactive, hidden and paused each come in turn.
    var phase = SchedulerBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (next) {
        final leaves = phase == AppLifecycleState.resumed && next != AppLifecycleState.resumed;
        phase = next;
        if (leaves) {
          store.writeNow();
          store.makeCover();
        }
      },
    );
    if (_showsInfo) {
      store.engine.faceNames().then(
        (names) {
          if (mounted) {
            setState(() => _faceNames = names);
          }
        },
        onError: (Object error) {
          print('editor: the face names did not come: $error');
        },
      );
    }
  }

  @override
  void dispose() {
    _builds.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final state = store.state;
            return Semantics(
              identifier: 'editor.root',
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showsInfo) ...[
                    _info('editor.seedInfo', widget.words.text(_seedInfo)),
                    _info('editor.textInfo', state.textInfo),
                    _info('editor.faceInfo', _faceNames),
                    _info('editor.soundInfo', state.soundInfo),
                  ],
                  Expanded(
                    child: _region('editor.previewRegion', [
                      // slot: preview
                      PreviewPane(
                        store: store,
                        words: widget.words,
                        builds: store.options['seed'] != null ? _built : null,
                      ),
                      // end slot: preview
                    ]),
                  ),
                  _region('editor.timelineRegion', [
                    // slot: timeline
                    Strip(key: ObjectKey(store), store: store),
                    // end slot: timeline
                  ]),
                  _region('editor.toolsRegion', [
                    // slot: tools
                    ToolsRow(store: store, words: widget.words),
                    // end slot: tools
                  ]),
                  if (state.selectedText != null)
                    _region('editor.textRegion', [
                      // slot: text
                      // Made anew for every text that gets selected, so it starts on the part of that text.
                      TextPanel(key: ValueKey(state.selectedText), store: store, words: widget.words),
                      // end slot: text
                    ]),
                  if (state.showsSound)
                    _region('editor.soundRegion', [
                      // slot: sound
                      // end slot: sound
                    ]),
                  if (state.showsClipPanel)
                    _region('editor.clipRegion', [
                      // slot: clip
                      // end slot: clip
                    ]),
                  _region('editor.exportRegion', [
                    // slot: export
                    ExportButton(store: store, words: widget.words),
                    // end slot: export
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The clips of the project, and how many of its media files are in the media folder, the file of its music
  /// among them. A half written file under another name does not count.
  core.Words get _seedInfo {
    final project = store.state.project;
    final names = [for (final media in project.media.values) media.fileName];
    final music = project.music;
    if (music != null) {
      names.add(music.file.fileName);
    }
    final files = names.where((name) => File('${store.mediaFolder.path}/$name').existsSync()).length;
    return core.Words('editor.seedInfo', ['${project.clips.length}', '$files']);
  }

  Widget _info(String identifier, String line) {
    return Semantics(
      identifier: identifier,
      container: true,
      child: Text(line, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
    );
  }

  /// A region at least 44 points high and as wide as the screen, its children in its middle.
  Widget _region(String identifier, List<Widget> children) {
    return Semantics(
      identifier: identifier,
      container: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Stack(alignment: Alignment.center, children: children),
      ),
    );
  }
}
