import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'sound_slider.dart';

/// The part `levels` of the sound panel. With music: the times of the music, `state.musicLabel`, as
/// `sound.levelsLabel`, so she sees where the music begins while she moves its start, then four sound sliders:
/// the volume of the music from 0 to 1, where it begins in the file in ticks, and its fade in and fade out in
/// ticks. The start slider shows only while `canSetMusicStart` is true, so its step fits into its range. With no
/// music the part shows the words of `music.none` as `sound.noMusic` and no slider. It decides nothing and holds
/// no state: each slider reads the project, the start sends its action once, at the end of a drag, the volume and
/// the fades send each value of a drag, the whole drag one step of undo, and Core holds every value inside its
/// limits. No level is read back from Swift. The part lays out from leading to trailing, so Arabic mirrors it. The
/// label of the times is fixed left to right, as the time of the preview is.
///
/// https://api.flutter.dev/flutter/widgets/Directionality-class.html
/// https://api.flutter.dev/flutter/painting/AlignmentDirectional-class.html
/// https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class MusicLevels extends StatelessWidget {
  const MusicLevels({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  /// The step of both fade sliders in ticks, from the plan (seam T).
  static const double _fadeStep = 300;

  @override
  Widget build(BuildContext context) {
    final state = store.state;
    final music = state.project.music;
    if (music == null) {
      final none = words.text(core.Words('music.none'));
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          identifier: 'sound.noMusic',
          container: true,
          label: none,
          excludeSemantics: true,
          child: Text(none, style: const TextStyle(fontSize: 17)),
        ),
      );
    }
    final label = state.musicLabel;
    final fade = core.SoundGeometry.maximumFade.ticks.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (label != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              identifier: 'sound.levelsLabel',
              container: true,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 17, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ),
        SoundSlider(
          identifier: 'sound.musicVolume',
          label: words.text(core.Words('music.volume')),
          value: music.volume,
          min: 0,
          max: 1,
          step: 0.05,
          send: (volume) => store.sendDragStep(core.EditorAction.sound(core.SoundAction.setMusicVolume(volume))),
          follows: true,
          ended: store.endDrag,
        ),
        if (state.canSetMusicStart)
          SoundSlider(
            identifier: 'sound.musicStart',
            label: words.text(core.Words('music.start')),
            value: music.start.ticks.toDouble(),
            min: 0,
            max: music.largestStart.ticks.toDouble(),
            step: core.SoundGeometry.startStep.ticks.toDouble(),
            send: (start) =>
                store.send(core.EditorAction.sound(core.SoundAction.setMusicStart(core.Time(ticks: start.round())))),
          ),
        SoundSlider(
          identifier: 'sound.fadeIn',
          label: words.text(core.Words('music.fadeIn')),
          value: music.fadeIn.ticks.toDouble(),
          min: 0,
          max: fade,
          step: _fadeStep,
          send: (ticks) =>
              store.sendDragStep(core.EditorAction.sound(core.SoundAction.setFadeIn(core.Time(ticks: ticks.round())))),
          follows: true,
          ended: store.endDrag,
        ),
        SoundSlider(
          identifier: 'sound.fadeOut',
          label: words.text(core.Words('music.fadeOut')),
          value: music.fadeOut.ticks.toDouble(),
          min: 0,
          max: fade,
          step: _fadeStep,
          send: (ticks) => store.sendDragStep(
            core.EditorAction.sound(core.SoundAction.setFadeOut(core.Time(ticks: ticks.round()))),
          ),
          follows: true,
          ended: store.endDrag,
        ),
      ],
    );
  }
}
