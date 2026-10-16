import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_store.dart';

/// The gestures on the picture, laid over it and drawing nothing: a tap selects the text nearest to the finger, a
/// scale recognizer moves the selected text with one finger, and a `Listener` sizes or turns it with two. They decide
/// nothing.
/// A gesture that begins with a text selected sends `pause`, then draws `reduce` of the state from its start under
/// the fingers: the compositor draws every pixel of a text, so each drawn project goes to the player through `show`
/// and the store keeps its state. On release the gesture sends the one value it changed, the text's centre, size or
/// rotation, so it is one step of undo. With no text selected they send nothing.
///
/// https://api.flutter.dev/flutter/widgets/Listener-class.html
/// https://api.flutter.dev/flutter/gestures/DragStartBehavior.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/gestures/ScaleGestureRecognizer-class.html
/// https://api.flutter.dev/flutter/gestures/ScaleStartDetails-class.html
/// https://api.flutter.dev/flutter/gestures/ScaleUpdateDetails-class.html
/// https://api.flutter.dev/flutter/gestures/ScaleEndDetails-class.html
/// https://api.flutter.dev/flutter/gestures/TapUpDetails-class.html
/// https://api.flutter.dev/flutter/widgets/BuildContext/size.html
class PictureGestures extends StatefulWidget {
  const PictureGestures({super.key, required this.store, required this.child});

  final EditorStore store;
  final Widget child;

  @override
  State<PictureGestures> createState() => _PictureGesturesState();
}

class _PictureGesturesState extends State<PictureGestures> {
  /// The state after the `pause` the gesture began with, null while no gesture on a text runs.
  core.EditorState? _start;

  /// The selected text in `_start`.
  core.TextItem? _text;

  /// The state drawn last, null until the fingers changed the text.
  core.EditorState? _drawn;

  /// The place of the fingers the distance moved is counted from.
  Offset _focal = Offset.zero;

  /// With two fingers, true for a twist and false for a pinch, null until the fingers went far enough to tell.
  bool? _twist;

  /// True while two fingers size or turn the text: from their first move until the number of fingers changes.
  bool _pair = false;

  /// The fingers on the picture by pointer, the most of them since the first came down, and where the first came
  /// down.
  final Map<int, Offset> _fingers = {};
  int _most = 0;
  Offset _down = Offset.zero;

  /// The line from the second finger to the first, the scale and the angle of two fingers are counted from: taken
  /// once the two are `_floor` points apart, since fingers that come down at one point give no scale and no angle.
  /// Null until then, and again when the number of fingers changes.
  Offset? _from;

  /// The points two fingers must be apart before their line is taken.
  static const double _floor = 4;

  /// The points the fingers go, apart or around, before two fingers are a pinch or a twist: as m6's pinch and twist,
  /// the one that begins first takes the gesture.
  static const double _travel = 10;

  @override
  Widget build(BuildContext context) {
    // From the finger coming down, so the text stays under the finger and turns with it from the first move.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      dragStartBehavior: DragStartBehavior.down,
      onTapUp: _tapped,
      onScaleStart: _started,
      onScaleUpdate: _updated,
      onScaleEnd: _ended,
      // Under the recognizers, so it has each place before they report it.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _endPair();
          if (_fingers.isEmpty) {
            _most = 0;
            _down = event.localPosition;
          }
          _fingers[event.pointer] = event.localPosition;
          _most = math.max(_most, _fingers.length);
        },
        onPointerMove: (event) {
          _fingers[event.pointer] = event.localPosition;
          if (_fingers.length >= 2) {
            _paired();
          }
        },
        onPointerUp: (event) {
          _endPair();
          _fingers.remove(event.pointer);
        },
        onPointerCancel: (event) {
          _endPair();
          _fingers.remove(event.pointer);
        },
        child: widget.child,
      ),
    );
  }

  /// Points on the picture as canvas pixels. The picture has the shape of the canvas, so its width gives both lengths.
  double _canvasLength(double points, core.Canvas canvas) =>
      core.TextGeometry.canvasLength(ofPoints: points, pictureWidth: context.size?.width ?? 0, canvas: canvas);

  /// Selects the nearest text at the playhead, or at the last frame with the playhead at the end. Sends no `pause`.
  void _tapped(TapUpDetails details) {
    // A tap is one finger, as in m6.
    if (_most > 1) {
      return;
    }
    final state = widget.store.state;
    final canvas = state.project.canvas;
    final last = state.project.duration - core.Time.frame;
    final nearest = state.project.textNearest(
      nearestToX: _canvasLength(details.localPosition.dx, canvas),
      y: _canvasLength(details.localPosition.dy, canvas),
      at: last < state.playhead ? last : state.playhead,
    );
    if (nearest != null) {
      widget.store.send(core.EditorAction.text(core.TextAction.select(nearest)));
    }
  }

  /// Takes the state the gesture counts from, after a `pause`, when a text is selected.
  void _begin() {
    final store = widget.store;
    final selected = store.state.selectedText;
    final text = selected == null ? null : store.state.project.text(selected);
    _start = null;
    _text = null;
    _drawn = null;
    _twist = null;
    _from = null;
    if (text == null) {
      return;
    }
    store.send(core.EditorAction.pause);
    _start = store.state;
    _text = store.state.project.text(text.id);
  }

  /// The recognizer starts at the first move, and ends and starts again when a finger comes or goes, so each part
  /// with one number of fingers is a gesture of its own. The first part counts from where the finger came down. Two
  /// fingers are left to the `Listener`: the recognizer takes them only once their spread changed by 18 points, which
  /// a small pinch outward never does.
  void _started(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      return;
    }
    _begin();
    _focal = _most == 1 ? _down : details.localFocalPoint;
  }

  /// One finger moves the text by the distance moved.
  void _updated(ScaleUpdateDetails details) {
    final start = _start;
    final text = _text;
    if (details.pointerCount >= 2 || _pair || start == null || text == null) {
      return;
    }
    final canvas = start.project.canvas;
    final moved = details.localFocalPoint - _focal;
    _draw(
      core.reduce(
        start,
        core.EditorAction.text(
          core.TextAction.move(
            text.id,
            text.x + _canvasLength(moved.dx, canvas),
            text.y + _canvasLength(moved.dy, canvas),
          ),
        ),
      ),
    );
  }

  /// Two fingers size the text by the scale or turn it by the angle, in degrees clockwise as she sees it: not both,
  /// as m6's pinch and twist never ran together. The first of the two whose way passes `_travel` points takes the
  /// gesture, apart for a pinch and around for a twist, counted from the start. The gesture begins at the first move
  /// of two fingers, after the recognizer ended the part of one finger at the second finger's down.
  void _paired() {
    if (!_pair) {
      _pair = true;
      _begin();
    }
    final start = _start;
    final text = _text;
    if (start == null || text == null) {
      return;
    }
    final places = _fingers.values.take(2).toList();
    final line = places[0] - places[1];
    final from = _from ??= line.distance >= _floor ? line : null;
    if (from == null) {
      return;
    }
    final scale = line.distance / from.distance;
    var angle = line.direction - from.direction;
    if (angle > math.pi) {
      angle -= 2 * math.pi;
    } else if (angle <= -math.pi) {
      angle += 2 * math.pi;
    }
    // Apart: how far the distance between the fingers changed. Around: the arc of the angle at that distance.
    final apart = (line.distance - from.distance).abs();
    final around = line.distance * angle.abs();
    if (_twist == null && apart < _travel && around < _travel) {
      return;
    }
    final twist = _twist ??= around > apart;
    _draw(
      core.reduce(
        start,
        core.EditorAction.text(
          twist
              ? core.TextAction.turn(text.id, text.rotation + angle * 180 / math.pi)
              : core.TextAction.setStyle(text.id, text.style.copyWith(size: text.style.size * scale)),
        ),
      ),
    );
  }

  /// Ends the gesture of two fingers when a finger comes or goes. The `Listener` hears of it before the recognizer.
  void _endPair() {
    if (_pair) {
      _pair = false;
      _finish();
    }
  }

  /// Shows the state when its project differs from the one drawn last.
  void _draw(core.EditorState next) {
    final start = _start;
    if (start != null && next.project != (_drawn ?? start).project) {
      _drawn = next;
      _show(next.project);
    }
  }

  /// The recognizer's end of a part of one finger.
  void _ended(ScaleEndDetails details) {
    if (!_pair) {
      _finish();
    }
  }

  /// Sends the one value that changed, the centre, the style or the rotation, so the gesture is one step of undo. An
  /// end while a finger stays sends too: a finger that comes or goes ends a gesture.
  void _finish() {
    final text = _text;
    final project = _drawn?.project;
    _start = null;
    _text = null;
    _drawn = null;
    final drawn = text == null ? null : project?.text(text.id);
    if (text == null || drawn == null) {
      return;
    }
    final store = widget.store;
    if (drawn.x != text.x || drawn.y != text.y) {
      store.send(core.EditorAction.text(core.TextAction.move(text.id, drawn.x, drawn.y)));
    }
    if (drawn.style != text.style) {
      store.send(core.EditorAction.text(core.TextAction.setStyle(text.id, drawn.style)));
    }
    if (drawn.rotation != text.rotation) {
      store.send(core.EditorAction.text(core.TextAction.turn(text.id, drawn.rotation)));
    }
  }

  /// The drawn project to the player, paused and with the playhead it has.
  void _show(core.Project project) {
    final store = widget.store;
    final id = store.textureId;
    if (id == null) {
      return;
    }
    final String json;
    try {
      json = _projectJson(project);
    } catch (error) {
      print('editor: the preview was not shown: $error');
      return;
    }
    store.engine.show(id, json, store.mediaFolder.path, null, false).catchError((Object error) {
      print('editor: the preview was not shown: $error');
    });
  }

  // slot: punch-in
  // end slot: punch-in
}

/// The project as the `project` member of the draft JSON, the form the store sends it to Swift in.
String _projectJson(core.Project project) {
  final draft = core.Draft(project: project, exportSettings: core.ExportSettings.startChoice, changed: DateTime.now());
  final json = jsonDecode(utf8.decode(core.encodeDraft(draft))) as Map<String, Object?>;
  return jsonEncode(json['project']);
}
