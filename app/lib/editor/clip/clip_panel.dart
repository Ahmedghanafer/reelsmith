import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import '../sound/sound_slider.dart';

/// The clip panel of the selected clip: one row with Delete before and Delete after the playhead, then, only while
/// the clip's media has sound, the slider of the clip's volume from 0 to 2, then the framing row, and on a test start
/// the framing of the clip as one line. It holds no state: Core says whether a button is enabled and whether the
/// slider shows, a tap sends one action, and the slider sends `setVolumeOfClip` at each value of a drag, the whole
/// drag one step of undo. It lays out from leading to trailing, so Arabic mirrors it.
///
/// The framing row is the container `clip.framing`: Fit and Fill (the picked one bold and selected), Blur (bold and
/// selected while the backdrop is blurred), All clips, then the guide button, which turns the Instagram guide over
/// the picture on and off and is disabled on a canvas with no guide.
///
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/material/IconButton-class.html
/// https://api.flutter.dev/flutter/material/MaterialTapTargetSize.html
/// https://api.flutter.dev/flutter/widgets/FittedBox-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
/// https://api.flutter.dev/flutter/foundation/ValueKey-class.html
class ClipPanel extends StatelessWidget {
  const ClipPanel({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  /// On a test start (a seed or `-drafts`), as the info lines of the editor.
  bool get _showsInfo => store.options['seed'] != null || store.options['drafts'] != null;

  @override
  Widget build(BuildContext context) {
    final state = store.state;
    core.Clip? framed;
    for (final clip in state.project.clips) {
      if (clip.id == state.selection) {
        framed = clip;
      }
    }
    final volumed = state.showsClipVolume ? framed : null;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          _row(32, [
            _text('clip.cutBefore', null, state.canCutBefore ? () => store.send(core.EditorAction.cutBefore) : null),
            _text('clip.cutAfter', null, state.canCutAfter ? () => store.send(core.EditorAction.cutAfter) : null),
          ]),
          if (volumed != null)
            // Made anew for each clip, so a drag begun on one clip is never sent to the next one selected.
            SoundSlider(
              key: ValueKey(volumed.id),
              identifier: 'clip.volume',
              label: words.text(core.Words('clip.volume')),
              value: volumed.volume,
              min: 0,
              max: 2,
              step: 0.05,
              send: (volume) =>
                  store.sendDragStep(core.EditorAction.sound(core.SoundAction.setVolumeOfClip(volumed.id, volume))),
              follows: true,
              ended: store.endDrag,
            ),
          if (framed != null) _framing(context, state, framed),
          if (_showsInfo)
            Semantics(
              identifier: 'clip.frameInfo',
              container: true,
              child: Text(
                state.frameInfo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _framing(BuildContext context, core.EditorState state, core.Clip clip) {
    final framing = clip.framing;
    final hasGuide = core.InstagramGuide.safeArea(state.project.canvas) != null;
    void frame(core.FrameAction action) => store.send(core.EditorAction.frame(action));
    return Semantics(
      identifier: 'clip.framing',
      container: true,
      explicitChildNodes: true,
      child: _row(12, [
        _text('clip.fit', framing.fit == core.Fit.fit, () => frame(core.FrameAction.setFit(clip.id, core.Fit.fit))),
        _text('clip.fill', framing.fit == core.Fit.fill, () => frame(core.FrameAction.setFit(clip.id, core.Fit.fill))),
        _text('clip.blur', framing.backdrop == core.Backdrop.blurred, () {
          // Read at the tap, so a second tap before the next build still turns the backdrop back.
          var now = framing.backdrop;
          for (final each in store.state.project.clips) {
            if (each.id == clip.id) {
              now = each.framing.backdrop;
            }
          }
          frame(
            core.FrameAction.setBackdrop(
              clip.id,
              now == core.Backdrop.blurred ? core.Backdrop.black : core.Backdrop.blurred,
            ),
          );
        }),
        _text('clip.applyAll', null, () => frame(core.FrameAction.applyToAll(clip.id))),
        // Turns the Instagram guide over the picture on and off. Only the 9:16 canvas has one.
        _guideButton(hasGuide),
      ]),
    );
  }

  /// A 44 by 44 point icon button, selected while the guide shows. On iOS Material pads an icon button to a 48 point
  /// target, so the target is shrink wrapped and the box fixed at 44.
  Widget _guideButton(bool enabled) {
    final tap = enabled ? () => store.showsGuide = !store.showsGuide : null;
    return Semantics(
      identifier: 'clip.guide',
      container: true,
      button: true,
      enabled: enabled,
      selected: store.showsGuide,
      label: words.text(core.Words('clip.guide')),
      onTap: tap,
      excludeSemantics: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: tap,
          icon: const Icon(Icons.crop_free),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ),
    );
  }

  /// A row at least 44 points high with its children in its middle, scaled down whole on a screen too narrow for it,
  /// never cut.
  Widget _row(double spacing, List<Widget> children) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, spacing: spacing, children: children),
        ),
      ),
    );
  }

  /// A button of the words of its identifier. `selected` true makes it bold with the trait selected, null is a
  /// button that is never selected. Null `tap` disables it. The target is shrink wrapped and the height held at 44.
  Widget _text(String key, bool? selected, VoidCallback? tap) {
    final label = words.text(core.Words(key));
    return Semantics(
      identifier: key,
      container: true,
      button: true,
      enabled: tap != null,
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
