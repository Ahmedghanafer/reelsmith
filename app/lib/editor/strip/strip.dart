import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_store.dart';

/// The clips as blocks in one row at the scale of the strip, under a playhead line that stays in the middle. One
/// scale recognizer reads the fingers: with one pointer it scrubs, with two it sets the scale. A tap on a block
/// selects it, a tap anywhere else on the strip clears the selection. Never mirrored: every x is set from the left
/// at the scale, and the strip is fixed left to right.
///
/// The scale lives in this state, so each editor starts at the standard. Only a pinch changes it, and every x and
/// width on the strip, its handles and its bars reads it. Nothing clips the blocks: one that lies past the edge of
/// the screen keeps its node, as a view off the screen did in `m6`.
///
/// https://api.flutter.dev/flutter/gestures/ScaleGestureRecognizer-class.html
/// https://api.flutter.dev/flutter/gestures/ScaleStartDetails/pointerCount.html
/// https://api.flutter.dev/flutter/gestures/ScaleUpdateDetails/scale.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
/// https://api.flutter.dev/flutter/widgets/Positioned-class.html
/// https://api.flutter.dev/flutter/widgets/Stack/clipBehavior.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class Strip extends StatefulWidget {
  const Strip({super.key, required this.store});

  final EditorStore store;

  @override
  State<Strip> createState() => StripState();
}

class StripState extends State<Strip> {
  /// The points a second of every x and width on the strip.
  core.TimelineScale scale = core.TimelineScale.standard;

  core.TimelineScale _pinchStart = core.TimelineScale.standard;
  double _scrubStart = 0;
  /// Where the last pointer came down, the start of a scrub, so the slop before the recognizer starts is not lost.
  double _downX = 0;

  /// True from the moment a second pointer joins until the next first pointer comes down: the pointer left after
  /// a pinch scrubs nothing, as `m6`'s pan of one touch did not.
  bool _pinching = false;

  /// The pointers down on the strip.
  int _pointers = 0;

  EditorStore get store => widget.store;

  /// Every row of the strip, read by the blocks, the trim handles, the text row and the music row.
  core.StripRows get rows => core.StripRows.of(folded: _folded, textSelected: store.state.selectedText != null);

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: double.infinity,
        height: rows.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final middle = constraints.maxWidth / 2;
            final left = middle - scale.x(store.state.playhead);
            return Listener(
              onPointerDown: (event) {
                if (_pointers == 0) {
                  _pinching = false;
                }
                _pointers++;
                _downX = event.localPosition.dx;
              },
              onPointerUp: (event) => _pointers--,
              onPointerCancel: (event) => _pointers--,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onScaleStart: _started,
                onScaleUpdate: _updated,
                onTapUp: (details) => _tapped(details.localPosition, left),
                // slot: recognizers
                // end slot: recognizers
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final (index, clip) in store.state.project.clips.indexed) _block(context, clip, index + 1, left),
                    // Views above the blocks go here, below the playhead, at `left` plus their x at the scale.
                    // slot: handles
                    // end slot: handles
                    // slot: music-row
                    // end slot: music-row
                    // slot: text-row
                    // end slot: text-row
                    Positioned(
                      left: middle - 1,
                      top: 0,
                      width: 2,
                      height: rows.height,
                      child: Semantics(
                        identifier: 'editor.playhead',
                        container: true,
                        value: store.state.playhead.clockText,
                        child: ColoredBox(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The block of the clip at its position, `left` being the x of time zero. Its label is the text on it: the
  /// position, then the length. Its value is `clipInfo`. A selected block has a yellow border of 3 points, the
  /// others one of 1 in the colour of the background.
  Widget _block(BuildContext context, core.Clip clip, int position, double left) {
    final theme = Theme.of(context);
    final project = store.state.project;
    final selected = clip.id == store.state.selection;
    final rows = this.rows;
    final width = scale.width(clip.duration);
    final words = '$position${_folded ? ' ' : '\n'}${clip.duration.clockText}';
    var x = left + scale.x(project.start(clip.id) ?? core.Time.zero);
    Widget child = Semantics(
      identifier: 'editor.clip.$position',
      container: true,
      label: words,
      value: project.clipInfo(clip.id),
      selected: selected,
      excludeSemantics: true,
      child: ClipRect(
        child: ColoredBox(
          color: theme.colorScheme.outline,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ..._tiles(clip, width, rows.clipHeight),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    width: selected ? 3 : 1,
                    color: selected
                        ? (theme.brightness == Brightness.light ? const Color(0xFFFFCC00) : const Color(0xFFFFD60A))
                        : theme.scaffoldBackgroundColor,
                  ),
                ),
                // White with a dark shadow, readable on any frame, as in m6.
                child: Center(
                  child: Text(
                    words,
                    textAlign: TextAlign.center,
                    maxLines: _folded ? 1 : 2,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: Color(0xFFFFFFFF),
                      shadows: [Shadow(color: Color(0xFF000000), offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // slot: reorder
    // end slot: reorder
    return Positioned(left: x, top: rows.clipY, width: width, height: rows.clipHeight, child: child);
  }

  // slot: frames
  /// The blocks are thin and show no frames.
  bool get _folded => false;

  /// The tiles of frames on a block, under its label.
  List<Widget> _tiles(core.Clip clip, double width, double height) => const [];
  // end slot: frames

  /// One pointer starts a scrub: `pause`, and the playhead's x is kept. Two start a pinch from the scale now. A
  /// pointer that comes or goes ends the gesture and starts it again with the new count.
  void _started(ScaleStartDetails details) {
    if (details.pointerCount > 1) {
      _pinching = true;
      _pinchStart = scale;
      return;
    }
    if (_pinching) {
      return;
    }
    _scrubStart = scale.x(store.state.playhead);
    store.send(core.EditorAction.pause);
  }

  /// A scrub sends `movePlayhead`: the strip follows the finger, so a drag to the left moves to a later time, and
  /// Core keeps the time inside the project. A pinch sets the scale to the scale at its start times its factor,
  /// held by Core, and sends nothing: the playhead stays in the middle on its time.
  void _updated(ScaleUpdateDetails details) {
    if (_pinching) {
      if (details.pointerCount > 1) {
        setState(() => scale = _pinchStart.zoomed(details.scale));
      }
      return;
    }
    final x = _scrubStart - (details.localFocalPoint.dx - _downX);
    store.send(core.EditorAction.movePlayhead(scale.time(x)));
  }

  /// A tap on the row of blocks selects the clip under it. A tap anywhere else on the strip, beside the row or in
  /// the band above or below it, sends `clearSelection`.
  void _tapped(Offset point, double left) {
    final rows = this.rows;
    final x = point.dx - left;
    final inRow =
        x >= 0 &&
        x < scale.width(store.state.project.duration) &&
        point.dy >= rows.clipY &&
        point.dy < rows.clipY + rows.clipHeight;
    final clip = inRow ? store.state.project.clip(scale.time(x)) : null;
    store.send(clip == null ? core.EditorAction.clearSelection : core.EditorAction.select(clip.id));
  }
}
