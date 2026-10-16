import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'add_clips.dart';

/// The row of the two edit buttons, the text button, the sound button, the button that adds clips and, at its
/// trailing end, the button that folds the frames of the blocks, 20 points apart. It decides nothing: Core says
/// whether a button is enabled, and a tap sends one action. The row lays out from leading to trailing, so Arabic
/// mirrors it, and it is scaled down whole on a screen too narrow for it, never cut.
///
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/material/IconButton-class.html
/// https://api.flutter.dev/flutter/material/MaterialTapTargetSize.html
/// https://api.flutter.dev/flutter/widgets/FittedBox-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class ToolsRow extends StatelessWidget {
  const ToolsRow({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  Widget build(BuildContext context) {
    final state = store.state;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          _text('editor.split', 'tools.split', state.canSplit ? () => store.send(core.EditorAction.split) : null),
          _text(
            'editor.delete',
            'tools.delete',
            state.canDelete ? () => store.send(core.EditorAction.deleteSelected) : null,
          ),
          _text(
            'editor.addText',
            'tools.text',
            state.canAddText ? () => store.send(const core.EditorAction.text(core.TextAction.add)) : null,
          ),
          _text(
            'editor.sound',
            'tools.sound',
            state.canOpenSound ? () => store.send(const core.EditorAction.sound(core.SoundAction.open)) : null,
          ),
          // slot: add-clips
          AddClips(store: store, button: (tap) => _icon('editor.addClips', 'tools.add', Icons.add, tap)),
          // end slot: add-clips
          // slot: fold
          // Folds the blocks of the strip to thin ones and back. No action of Core: the fold is the store's.
          _icon(
            'editor.frames',
            'tools.frames',
            Icons.view_week_outlined,
            () => store.framesFolded = !store.framesFolded,
          ),
          // end slot: fold
        ],
      ),
    );
  }

  /// A button of words, with its identifier and the label of its word key. Null `tap` disables it.
  Widget _text(String identifier, String key, VoidCallback? tap) {
    final label = words.text(core.Words(key));
    return _semantics(
      identifier,
      label,
      tap,
      TextButton(
        onPressed: tap,
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontSize: 17),
        ),
        child: Text(label),
      ),
    );
  }

  /// A 44 by 44 point icon button. On iOS Material pads an icon button to a 48 point target, so the target is
  /// shrink wrapped and the box fixed at 44.
  Widget _icon(String identifier, String key, IconData icon, VoidCallback? tap) {
    return _semantics(
      identifier,
      words.text(core.Words(key)),
      tap,
      SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: tap,
          icon: Icon(icon),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ),
    );
  }

  Widget _semantics(String identifier, String label, VoidCallback? tap, Widget child) {
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      enabled: tap != null,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: child,
    );
  }
}
