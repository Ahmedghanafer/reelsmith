import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'music_levels.dart';
import 'sound_clips.dart';

/// The sound panel: one row with the three part buttons and, at its trailing end, the done button, and under the
/// row the part that shows, at least 184 points high. Which part shows is the one state of the panel, music when the
/// panel is made. Each part is a slot of this file, and a slot that is empty shows nothing under the row. The done
/// button only clears the selection, which closes the panel. The row lays out from leading to trailing, so Arabic
/// mirrors it.
///
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/material/MaterialTapTargetSize.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class SoundPanel extends StatefulWidget {
  const SoundPanel({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  State<SoundPanel> createState() => _SoundPanelState();
}

enum _Part { music, levels, clips }

class _SoundPanelState extends State<SoundPanel> {
  _Part _part = _Part.music;

  EditorStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              spacing: 24,
              children: [
                _tab(_Part.music, 'sound.tab.music'),
                _tab(_Part.levels, 'sound.tab.levels'),
                _tab(_Part.clips, 'sound.tab.clips'),
                const Spacer(),
                _button('sound.done', null, () => store.send(core.EditorAction.clearSelection)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 184),
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_part == _Part.music) ...[
                    // slot: music
                    // end slot: music
                  ],
                  if (_part == _Part.levels) ...[
                    // slot: levels
                    MusicLevels(store: store, words: widget.words),
                    // end slot: levels
                  ],
                  if (_part == _Part.clips) ...[
                    // slot: clips
                    SoundClips(store: store, words: widget.words),
                    // end slot: clips
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One part button. Its word key is its identifier, and the part that shows is bold and has the trait selected.
  Widget _tab(_Part shown, String key) => _button(key, _part == shown, () => setState(() => _part = shown));

  /// A button of the words of its identifier, with the trait selected when `selected` is true and bold words then.
  /// `selected` null is a button that is never selected. On iOS Material pads a button to a 48 point target, so the
  /// target is shrink wrapped and the height held at 44.
  Widget _button(String key, bool? selected, VoidCallback tap) {
    final label = widget.words.text(core.Words(key));
    return Semantics(
      identifier: key,
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: TextButton(
        onPressed: tap,
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 44),
          textStyle: TextStyle(fontSize: 17, fontWeight: selected == true ? FontWeight.bold : FontWeight.normal),
        ),
        child: Text(label),
      ),
    );
  }
}
