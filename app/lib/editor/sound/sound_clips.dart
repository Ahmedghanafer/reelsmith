import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'sound_slider.dart';

/// The part `clips` of the sound panel: the slider `sound.clipVolume` for the sound of every clip and, under it,
/// the toggle `sound.clipsMuted`. It decides nothing and holds no state: both read the project, the slider sends
/// `setClipVolume` at every step of a drag, the whole drag one step of undo, and the toggle `muteClips`, and Core
/// holds the volume between 0 and 1. A toggle that is on has the trait selected and a tinted background. The part
/// lays out from leading to trailing, so Arabic mirrors it.
///
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/painting/StadiumBorder-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class SoundClips extends StatelessWidget {
  const SoundClips({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  Widget build(BuildContext context) {
    final project = store.state.project;
    final muted = project.clipsMuted;
    final tint = Theme.of(context).colorScheme.primary;
    final label = words.text(core.Words('sound.clipsMuted'));
    // Read at the call, so two quick taps turn it twice.
    void toggle() =>
        store.send(core.EditorAction.sound(core.SoundAction.muteClips(!store.state.project.clipsMuted)));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        SoundSlider(
          identifier: 'sound.clipVolume',
          label: words.text(core.Words('sound.clipVolume')),
          value: project.clipVolume,
          min: 0,
          max: 1,
          step: 0.05,
          send: (volume) => store.sendDragStep(core.EditorAction.sound(core.SoundAction.setClipVolume(volume))),
          follows: true,
          ended: store.endDrag,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              identifier: 'sound.clipsMuted',
              container: true,
              button: true,
              selected: muted,
              label: label,
              onTap: toggle,
              excludeSemantics: true,
              child: TextButton(
                onPressed: toggle,
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  backgroundColor: muted ? tint.withValues(alpha: 0.15) : Colors.transparent,
                  textStyle: const TextStyle(fontSize: 17),
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
