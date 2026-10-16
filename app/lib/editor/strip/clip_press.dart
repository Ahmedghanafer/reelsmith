import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_store.dart';

/// What the strip draws while a press or a drag of a trim handle runs, one for each strip. The gesture sets it at
/// each step and redraws the strip, and the slots `handles` and `reorder` of the strip read it.
///
/// https://api.dart.dev/stable/dart-core/Expando-class.html
class StripDrag {
  StripDrag._();

  static final Expando<StripDrag> _strips = Expando<StripDrag>();

  /// The one of the strip.
  static StripDrag of(Object strip) => _strips[strip] ??= StripDrag._();

  /// The state drawn in place of the store's while a gesture runs, null while none runs.
  core.EditorState? get drawn => _drawn;
  core.EditorState? _drawn;

  /// The clips of `drawn` in the order they are painted: the lifted one last, so it lies above the others.
  List<core.Clip> get painted => _painted;
  List<core.Clip> _painted = const [];

  /// The pressed clip and the x of the left end its block is drawn at, time zero being 0. Null while no press runs.
  ({core.ClipID clip, double left})? get lifted => _lifted;
  ({core.ClipID clip, double left})? _lifted;

  /// True while the slot `reorder` places a block of `drawn`, so that block is not sent on to another again.
  bool placing = false;

  /// Draws the state, with the block of a press lifted. Null draws the store's state again.
  void draw(core.EditorState? state, {({core.ClipID clip, double left})? lifted}) {
    _drawn = state;
    _lifted = state == null ? null : lifted;
    final clips = state?.project.clips ?? const <core.Clip>[];
    _painted = List<core.Clip>.unmodifiable([
      for (final clip in clips)
        if (clip.id != _lifted?.clip) clip,
      for (final clip in clips)
        if (clip.id == _lifted?.clip) clip,
    ]);
  }
}

/// The press and drag that moves a clip on the strip, over the row of blocks. It decides nothing: the place a block
/// is let go at is `dropPosition` of the time of the block's left end moved by the finger since it came down, so a
/// press held still keeps its place, and the move is `reduce`. It begins on a block after half a second. While the
/// finger moves the strip draws `reduce` of the state from the start with the move so far, the pressed block lifted
/// under the finger, and one `moveClip` is sent on release. It lies below the trim handles and the text bars, so a
/// press on them never reaches it, and it lets every touch through to the blocks and the strip. Once it has begun the
/// strip's scrub and tap lose the touch.
///
/// https://api.flutter.dev/flutter/gestures/LongPressGestureRecognizer-class.html
/// https://api.flutter.dev/flutter/gestures/LongPressStartDetails-class.html
/// https://api.flutter.dev/flutter/gestures/LongPressMoveUpdateDetails-class.html
/// https://api.flutter.dev/flutter/gestures/LongPressEndDetails-class.html
/// https://api.flutter.dev/flutter/gestures/GestureLongPressCancelCallback.html
/// https://api.flutter.dev/flutter/widgets/RawGestureDetector-class.html
/// https://api.flutter.dev/flutter/rendering/HitTestBehavior.html
class ClipPress extends StatefulWidget {
  const ClipPress({super.key, required this.store, required this.scale, required this.drag, required this.redraw});

  final EditorStore store;
  final core.TimelineScale scale;
  final StripDrag drag;

  /// Draws the strip again.
  final VoidCallback redraw;

  @override
  State<ClipPress> createState() => _ClipPressState();
}

class _ClipPressState extends State<ClipPress> {
  /// The state at the start of the press, null while no press runs.
  core.EditorState? _start;

  /// The clip the press began on, null while no press runs.
  core.ClipID? _clip;

  /// The x of the left end of the pressed block when the press began, time zero being 0.
  double _blockStartX = 0;

  /// The x on the screen where the finger came down.
  double _fingerStartX = 0;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 500), debugOwner: this),
          (recognizer) => recognizer
            ..onLongPressStart = _began
            ..onLongPressMoveUpdate = ((details) => _moved(details.globalPosition.dx))
            ..onLongPressEnd = ((details) => _ended(details.globalPosition.dx))
            ..onLongPressCancel = _cancelled,
        ),
      },
      child: const SizedBox.expand(),
    );
  }

  /// The press starts by sending `pause`, so the state of the store stands still under the preview.
  void _began(LongPressStartDetails details) {
    final store = widget.store;
    final clip = store.state.project.clip(widget.scale.time(details.localPosition.dx));
    if (clip == null) {
      return;
    }
    store.send(core.EditorAction.pause);
    final start = core.reduce(store.state, core.EditorAction.pause);
    _start = start;
    _clip = clip.id;
    _blockStartX = widget.scale.x(start.project.start(clip.id) ?? core.Time.zero);
    _fingerStartX = details.globalPosition.dx;
    _moved(_fingerStartX);
  }

  void _moved(double fingerX) {
    final start = _start;
    final clip = _clip;
    if (start == null || clip == null) {
      return;
    }
    final left = _blockStartX + fingerX - _fingerStartX;
    final position = start.project.dropPosition(of: clip, at: widget.scale.time(left));
    if (position == null) {
      return;
    }
    widget.drag.draw(core.reduce(start, core.EditorAction.moveClip(clip, position)), lifted: (clip: clip, left: left));
    widget.redraw();
  }

  void _ended(double fingerX) {
    final start = _start;
    final clip = _clip;
    if (start == null || clip == null) {
      return;
    }
    final position = start.project.dropPosition(
      of: clip,
      at: widget.scale.time(_blockStartX + fingerX - _fingerStartX),
    );
    _stop();
    if (position != null) {
      widget.store.send(core.EditorAction.moveClip(clip, position));
    }
  }

  /// A cancelled press draws the state of the store again and sends nothing.
  void _cancelled() {
    if (_start != null) {
      _stop();
    }
  }

  void _stop() {
    _start = null;
    _clip = null;
    widget.drag.draw(null);
    widget.redraw();
  }
}

/// The block of a running press: larger and with a shadow, its tiles with it.
///
/// https://api.flutter.dev/flutter/widgets/Transform/Transform.scale.html
/// https://api.flutter.dev/flutter/painting/BoxShadow-class.html
Widget liftedBlock(Widget block) {
  return Transform.scale(
    scale: 1.08,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: block,
    ),
  );
}
