import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_screen.dart';
import '../editor_store.dart';
import 'clip_press.dart';

/// Wide enough to be pressed in its middle.
const double _width = 24;

/// The two trim handles of the selected clip, outside its edges and as high as the row of blocks, for the slot
/// `handles` of the strip, `left` being the x of time zero. They are placed by the state the strip draws, so a
/// handle follows its edge while it is dragged. None while no clip is selected, and none while a block is lifted by
/// a press, so no handle is drawn over the block under the finger. Never mirrored: the start handle is at the left
/// edge in every language.
List<Widget> trimHandles({
  required EditorStore store,
  required core.TimelineScale scale,
  required core.StripRows rows,
  required double left,
  required StripDrag drag,
  required VoidCallback redraw,
}) {
  final state = drag.drawn ?? store.state;
  final selection = state.selection;
  if (drag.lifted != null || selection == null) {
    return const [];
  }
  final clip = state.project.clips.where((candidate) => candidate.id == selection).firstOrNull;
  final start = state.project.start(selection);
  if (clip == null || start == null) {
    return const [];
  }
  final x = left + scale.x(start);
  final right = x + scale.width(clip.duration);
  return [
    for (final isStart in const [true, false])
      Positioned(
        key: ValueKey<String>(isStart ? 'editor.trim.start' : 'editor.trim.end'),
        left: isStart ? x - _width : right,
        top: rows.clipY,
        width: _width,
        height: rows.clipHeight,
        child: TrimHandle(isStart: isStart, store: store, scale: scale, drag: drag, redraw: redraw),
      ),
  ];
}

/// One of the two trim handles of the selected clip. It decides nothing: a drag draws `reduce` of the state from its
/// start with the trim for the points moved so far, and one trim action is sent on release. A tap on it does nothing,
/// and a drag on it never scrubs: its recognizers take the touch before the strip's.
///
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector/dragStartBehavior.html
/// https://api.flutter.dev/flutter/gestures/DragStartDetails-class.html
/// https://api.flutter.dev/flutter/gestures/DragUpdateDetails-class.html
/// https://api.flutter.dev/flutter/widgets/BuildContext/findAncestorWidgetOfExactType.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class TrimHandle extends StatefulWidget {
  const TrimHandle({
    super.key,
    required this.isStart,
    required this.store,
    required this.scale,
    required this.drag,
    required this.redraw,
  });

  final bool isStart;
  final EditorStore store;
  final core.TimelineScale scale;
  final StripDrag drag;

  /// Draws the strip again.
  final VoidCallback redraw;

  @override
  State<TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<TrimHandle> {
  /// The state at the start of the drag, null while no drag runs.
  core.EditorState? _start;

  /// The x on the screen where the finger came down.
  double _fingerStartX = 0;

  /// The points moved at the last step.
  double _moved = 0;

  @override
  Widget build(BuildContext context) {
    final key = widget.isStart ? 'trim.start' : 'trim.end';
    final words = context.findAncestorWidgetOfExactType<EditorScreen>()?.words;
    final light = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      identifier: widget.isStart ? 'editor.trim.start' : 'editor.trim.end',
      container: true,
      label: words?.text(core.Words(key)) ?? key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        dragStartBehavior: DragStartBehavior.down,
        // A tap on a handle does nothing. Without it the strip's tap would select the block under the handle.
        onTap: () {},
        onHorizontalDragStart: _began,
        onHorizontalDragUpdate: (details) => _step(details.globalPosition.dx - _fingerStartX),
        onHorizontalDragEnd: (_) => _ended(),
        onHorizontalDragCancel: _cancelled,
        // iOS's system yellow, as the border of the selected block.
        child: ColoredBox(color: light ? const Color(0xFFFFCC00) : const Color(0xFFFFD60A)),
      ),
    );
  }

  core.EditorAction _action(core.ClipID clip, double moved) {
    final scale = widget.scale;
    return widget.isStart
        ? core.EditorAction.trimStart(clip, scale.trimAmount(moved))
        : core.EditorAction.trimEnd(clip, scale.trimAmount(-moved));
  }

  /// The drag starts by sending `pause`, so the state of the store stands still under the preview.
  void _began(DragStartDetails details) {
    final store = widget.store;
    store.send(core.EditorAction.pause);
    _start = core.reduce(store.state, core.EditorAction.pause);
    _fingerStartX = details.globalPosition.dx;
    _step(0);
  }

  void _step(double moved) {
    final start = _start;
    final clip = start?.selection;
    if (start == null || clip == null) {
      return;
    }
    _moved = moved;
    widget.drag.draw(core.reduce(start, _action(clip, moved)));
    widget.redraw();
  }

  void _ended() {
    final clip = _start?.selection;
    if (clip == null) {
      _start = null;
      return;
    }
    _start = null;
    widget.drag.draw(null);
    widget.redraw();
    widget.store.send(_action(clip, _moved));
  }

  /// A cancelled drag draws the state of the store again and sends nothing.
  void _cancelled() {
    if (_start == null) {
      return;
    }
    _start = null;
    widget.drag.draw(null);
    widget.redraw();
  }
}
