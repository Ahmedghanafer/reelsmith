import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'preview_picture.dart';

/// The preview of the editor: the picture in the shape of the project's canvas, and under it the row of the
/// button to the projects, the play button, the time label and, at its trailing end, undo, redo and Save, 8
/// points apart so all six fit the width of the phone. It decides nothing: the label is `timeLabel`, the icon
/// follows `isPlaying`, play is enabled by `canPlay` and a tap sends `play` or `pause`. Undo and redo are always
/// shown and enabled by `canUndo` and `canRedo`, so nothing in the row moves when one is enabled. Save is always
/// enabled and writes the draft. The button to the projects is always enabled and closes the store, which
/// writes what is not written, makes the cover and takes her back to the start screen. Never mirrored: the whole
/// pane is fixed left to right.
///
/// https://api.flutter.dev/flutter/widgets/AspectRatio-class.html
/// https://api.flutter.dev/flutter/widgets/Directionality-class.html
/// https://api.flutter.dev/flutter/material/IconButton-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
/// https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html
class PreviewPane extends StatelessWidget {
  const PreviewPane({super.key, required this.store, required this.words, this.builds});

  final EditorStore store;
  final WordsText words;

  /// The value of `editor.picture`, given on a seeded start only.
  final int? builds;

  @override
  Widget build(BuildContext context) {
    final state = store.state;
    final canvas = state.project.canvas;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        spacing: 8,
        children: [
          // The picture is as large as fits whole in the space above the row, and stands in its middle.
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: canvas.width / canvas.height,
                child: PreviewPicture(textureId: store.textureId, builds: builds),
              ),
            ),
          ),
          Row(
            spacing: 8,
            children: [
              _button(
                'editor.projects',
                core.Words('editor.projects'),
                Icons.grid_view,
                () => store.close(),
              ),
              _button(
                'editor.play',
                core.Words(state.isPlaying ? 'preview.pause' : 'preview.play'),
                state.isPlaying ? Icons.pause : Icons.play_arrow,
                // Read at the tap, so a pause the player sent a moment ago is seen.
                state.canPlay
                    ? () => store.send(store.state.isPlaying ? core.EditorAction.pause : core.EditorAction.play)
                    : null,
              ),
              // The space between play and undo: the label stands at its start, and is cut on a screen too narrow
              // for it rather than push the buttons off.
              Expanded(
                child: Semantics(
                  identifier: 'editor.time',
                  container: true,
                  child: Text(
                    state.timeLabel,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(fontSize: 15, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
              _button(
                'editor.undo',
                core.Words('editor.undo'),
                Icons.undo,
                store.editing.canUndo ? store.undo : null,
              ),
              _button(
                'editor.redo',
                core.Words('editor.redo'),
                Icons.redo,
                store.editing.canRedo ? store.redo : null,
              ),
              _button('editor.save', core.Words('draft.save'), Icons.save_alt, store.write),
            ],
          ),
        ],
      ),
    );
  }

  /// A 44 point button with its identifier and the label of its word key. Null `tap` disables it.
  Widget _button(String identifier, core.Words label, IconData icon, VoidCallback? tap) {
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      enabled: tap != null,
      label: words.text(label),
      onTap: tap,
      excludeSemantics: true,
      child: IconButton(
        onPressed: tap,
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }
}
