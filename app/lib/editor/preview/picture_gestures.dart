import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_store.dart';

/// The gestures on the picture, laid over it and drawing nothing: a tap selects the text nearest to the finger, and
/// one scale recognizer moves the selected text with one finger and sizes and turns it with two. They decide nothing.
/// A gesture that begins with a text selected sends `pause`, then draws `reduce` of the state from its start under
/// the fingers: the compositor draws every pixel of a text, so each drawn project goes to the player through `show`
/// and the store keeps its state. On release the gesture sends the text's new centre, size and rotation, each only
/// when it changed, as one run of shaping and so one step of undo. With no text selected they send nothing.
///
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

  /// The place of the fingers when the recognizer started.
  Offset _focal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: _tapped,
      onScaleStart: _started,
      onScaleUpdate: _updated,
      onScaleEnd: _ended,
      child: widget.child,
    );
  }

  /// Points on the picture as canvas pixels. The picture has the shape of the canvas, so its width gives both lengths.
  double _canvasLength(double points, core.Canvas canvas) =>
      core.TextGeometry.canvasLength(ofPoints: points, pictureWidth: context.size?.width ?? 0, canvas: canvas);

  /// Selects the nearest text at the playhead, or at the last frame with the playhead at the end. Sends no `pause`.
  void _tapped(TapUpDetails details) {
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

  /// The recognizer starts at the first move, and ends and starts again when a finger comes or goes, so each part
  /// with one number of fingers is a gesture of its own.
  void _started(ScaleStartDetails details) {
    final store = widget.store;
    final selected = store.state.selectedText;
    final text = selected == null ? null : store.state.project.text(selected);
    _start = null;
    _text = null;
    _drawn = null;
    if (text == null) {
      return;
    }
    store.send(core.EditorAction.pause);
    _start = store.state;
    _text = store.state.project.text(text.id);
    _focal = details.localFocalPoint;
  }

  /// One finger moves the text by the distance moved. Two size it by the scale and turn it by the angle, in degrees
  /// clockwise as she sees it.
  void _updated(ScaleUpdateDetails details) {
    final start = _start;
    final text = _text;
    if (start == null || text == null) {
      return;
    }
    final core.EditorState next;
    if (details.pointerCount >= 2) {
      final sized = core.reduce(
        start,
        core.EditorAction.text(
          core.TextAction.setStyle(text.id, text.style.copyWith(size: text.style.size * details.scale)),
        ),
      );
      next = core.reduce(
        sized,
        core.EditorAction.text(core.TextAction.turn(text.id, text.rotation + details.rotation * 180 / math.pi)),
      );
    } else {
      final canvas = start.project.canvas;
      final moved = details.localFocalPoint - _focal;
      next = core.reduce(
        start,
        core.EditorAction.text(
          core.TextAction.move(
            text.id,
            text.x + _canvasLength(moved.dx, canvas),
            text.y + _canvasLength(moved.dy, canvas),
          ),
        ),
      );
    }
    if (next.project != (_drawn ?? start).project) {
      _drawn = next;
      _show(next.project);
    }
  }

  /// Sends what changed: the centre, the style and the rotation, all shaping of one text and so one step of undo.
  void _ended(ScaleEndDetails details) {
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
