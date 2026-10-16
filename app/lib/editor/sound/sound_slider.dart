import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// The slider of a sound value: its word, then the slider, from leading to trailing, so in Arabic the slider is
/// mirrored with its lowest end on the right. It shows `value` while it is not dragged and its own value during a
/// drag, moved in steps of `step` from `min` and never past `max`. Without `follows` it calls `send` once, when the
/// drag ends, and a change with no drag is sent at once: the start of the music builds a new item, so its drag must
/// not send at every step. With `follows` it calls `send` at every change of a drag and `ended` when the drag ends,
/// and after a change with no drag calls `send` then `ended`: a level refreshes the mix of the player item, so she
/// hears it follow her finger. A slider with `follows` that goes from the screen during a drag calls `ended` then,
/// so the run never stays open. It holds no limit: Core does.
///
/// The track left of the thumb is in the tint and the rest in the grey of the theme, light or dark, as on iOS. The
/// slider is one semantics node with the slider flag, its word as label and the place of the thumb in percent as
/// value, as iOS gives it for a slider.
///
/// https://api.flutter.dev/flutter/material/Slider-class.html
/// https://api.flutter.dev/flutter/material/Slider/onChangeStart.html
/// https://api.flutter.dev/flutter/material/Slider/onChangeEnd.html
/// https://api.flutter.dev/flutter/material/ThemeData/disabledColor.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
/// https://api.dart.dev/stable/dart-async/scheduleMicrotask.html
class SoundSlider extends StatefulWidget {
  const SoundSlider({
    super.key,
    required this.identifier,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.send,
    this.follows = false,
    this.ended,
  });

  final String identifier;
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final void Function(double) send;
  final bool follows;
  final VoidCallback? ended;

  @override
  State<SoundSlider> createState() => _SoundSliderState();
}

class _SoundSliderState extends State<SoundSlider> {
  /// The value of the slider while it is dragged, null while it is not.
  double? _dragged;

  @override
  void dispose() {
    if (widget.follows && _dragged != null) {
      _dragged = null;
      // The store tells its screens at once, which may not happen while the tree is torn down.
      final ended = widget.ended;
      if (ended != null) {
        scheduleMicrotask(ended);
      }
    }
    super.dispose();
  }

  /// The value on the step nearest to it, never past `max`.
  double _stepped(double moved) {
    final steps = ((moved - widget.min) / widget.step).round();
    return min(widget.min + steps * widget.step, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = widget.max - widget.min;
    final shown = (_dragged ?? widget.value).clamp(widget.min, widget.max).toDouble();
    final steps = range / widget.step;
    // A range that is a whole number of steps draws its steps as marks.
    final divisions = (steps - steps.round()).abs() < 1e-9 && steps.round() > 0 ? steps.round() : null;
    final share = range > 0 ? (shown - widget.min) / range : 0.0;
    return Row(
      spacing: 16,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 17)),
        Expanded(
          child: Semantics(
            identifier: widget.identifier,
            container: true,
            slider: true,
            label: widget.label,
            value: '${(share * 100).round()}%',
            excludeSemantics: true,
            child: Slider(
              value: shown,
              min: widget.min,
              max: widget.max,
              divisions: divisions,
              activeColor: theme.colorScheme.primary,
              inactiveColor: theme.disabledColor,
              onChangeStart: (_) => setState(() => _dragged = _dragged ?? widget.value),
              onChanged: (value) {
                final moved = _stepped(value);
                if (_dragged == null) {
                  widget.send(moved);
                  if (widget.follows) {
                    widget.ended?.call();
                  }
                } else {
                  setState(() => _dragged = moved);
                  if (widget.follows) {
                    widget.send(moved);
                  }
                }
              },
              onChangeEnd: (_) {
                final last = _dragged;
                if (last == null) {
                  return;
                }
                setState(() => _dragged = null);
                if (widget.follows) {
                  widget.ended?.call();
                } else {
                  widget.send(last);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
