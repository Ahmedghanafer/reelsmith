import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// The checks of the plan inside the breach (one segment per clip, each rectangle and backdrop by rule 84, a clip of the
// standard framing placed as today) stay in Swift: they read renderPlan.

/// A random source of our own with a fixed start number (SplitMix64). Dart's int wraps as Swift's UInt64 does under
/// &+ and &*, and >>> is the unsigned shift, so a start number gives the same run as in Swift.
class _Draw {
  int _state;

  _Draw(int startNumber) : _state = startNumber;

  int next() {
    _state = _state + 0x9E3779B97F4A7C15;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  /// A whole number from zero up to the count, the count itself left out: the next number read as unsigned,
  /// modulo the count.
  int below(int count) {
    final value = next();
    if (value >= 0) {
      return value % count;
    }
    return ((value >>> 1) % count * 2 + (value & 1)) % count;
  }
}

/// The outcomes of the frame actions. The runs must hold every one.
enum _Kind {
  fit('setFit that changes the state'),
  backdrop('setBackdrop that changes the state'),
  zoom('setZoom that changes the state'),
  offset('setOffset that changes the state'),
  all('applyToAll that changes the state'),
  held('a frame action whose value was held'),
  unknown('a frame action of a clip id that is not in the project'),
  notFinite('a frame action with a value that is not finite');

  final String rawValue;

  const _Kind(this.rawValue);
}

Clip? _clipOf(List<Clip> clips, ClipID id) {
  for (final clip in clips) {
    if (clip.id == id) {
      return clip;
    }
  }
  return null;
}

List<_Kind> _kinds(EditorAction action, EditorState before, EditorState after) {
  if (action is! EditorActionFrame) {
    return [];
  }
  final frameAction = action.frameAction;
  final clips = before.project.clips;
  final changed = after != before;
  final kinds = <_Kind>[];
  switch (frameAction) {
    case FrameActionSetFit(:final id) || FrameActionSetBackdrop(:final id) || FrameActionApplyToAll(:final id):
      if (_clipOf(clips, id) == null) {
        kinds.add(_Kind.unknown);
      }
    case FrameActionSetZoom(:final id, :final zoom):
      final clip = _clipOf(after.project.clips, id);
      if (!zoom.isFinite) {
        kinds.add(_Kind.notFinite);
      } else if (_clipOf(clips, id) == null) {
        kinds.add(_Kind.unknown);
      } else if (clip != null && clip.framing.zoom != zoom) {
        kinds.add(_Kind.held);
      }
    case FrameActionSetOffset(:final id, :final x, :final y):
      final clip = _clipOf(after.project.clips, id);
      if (!x.isFinite || !y.isFinite) {
        kinds.add(_Kind.notFinite);
      } else if (_clipOf(clips, id) == null) {
        kinds.add(_Kind.unknown);
      } else if (clip != null && (clip.framing.x != x || clip.framing.y != y)) {
        kinds.add(_Kind.held);
      }
  }
  if (changed) {
    switch (frameAction) {
      case FrameActionSetFit():
        kinds.add(_Kind.fit);
      case FrameActionSetBackdrop():
        kinds.add(_Kind.backdrop);
      case FrameActionSetZoom():
        kinds.add(_Kind.zoom);
      case FrameActionSetOffset():
        kinds.add(_Kind.offset);
      case FrameActionApplyToAll():
        kinds.add(_Kind.all);
    }
  }
  return kinds;
}

/// One time in four an id that no clip has, else the id of a clip of the project, as the merged guards draw.
ClipID _drawClip(_Draw draw, EditorState state) {
  final clips = state.project.clips;
  if (clips.isEmpty || draw.below(4) == 0) {
    return ClipID(state.project.nextClipID + draw.below(3));
  }
  return clips[draw.below(clips.length)].id;
}

/// Not finite, below 1, above 4, or from 1 to 4 in hundredths.
double _drawZoom(_Draw draw) {
  switch (draw.below(10)) {
    case 0:
      return double.nan;
    case 1:
      return double.infinity;
    case 2:
      return draw.below(100) / 100;
    case 3:
      return 4 + (1 + draw.below(500)) / 100;
    default:
      return 1 + draw.below(301) / 100;
  }
}

/// Not finite, far past every edge, or from minus 1 to 1 in hundredths.
double _drawShare(_Draw draw) {
  switch (draw.below(12)) {
    case 0:
      return double.nan;
    case 1:
      return double.negativeInfinity;
    case 2:
      final sign = draw.below(2) == 0 ? -1 : 1;
      return sign * (1 + draw.below(300) / 100);
    default:
      return (draw.below(201) - 100) / 100;
  }
}

/// Ten thousand ticks either way are past every limit of a trim, as the merged guards draw.
Time _drawAmount(_Draw draw) {
  switch (draw.below(4)) {
    case 0:
      return Time(ticks: 10000 + draw.below(40));
    case 1:
      return Time(ticks: -10000 - draw.below(40));
    default:
      return Time(ticks: draw.below(1601) - 800);
  }
}

final List<MediaInfo> _added = [
  TestClip.blue.info,
  TestClip.red.info,
  TestClip.green.info,
  TestClip.turned.info,
  TestPhoto.magenta.info,
];

/// 26 actions in 40 are frame actions, the rest split, move, the cuts, the trims, addClips, select and the playhead.
EditorAction _drawAction(_Draw draw, EditorState state) {
  final choice = draw.below(40);
  if (choice <= 4) {
    return EditorAction.frame(FrameAction.setFit(_drawClip(draw, state), draw.below(2) == 0 ? Fit.fit : Fit.fill));
  }
  if (choice <= 8) {
    return EditorAction.frame(
      FrameAction.setBackdrop(_drawClip(draw, state), draw.below(2) == 0 ? Backdrop.black : Backdrop.blurred),
    );
  }
  if (choice <= 14) {
    final clip = _drawClip(draw, state);
    return EditorAction.frame(FrameAction.setZoom(clip, _drawZoom(draw)));
  }
  if (choice <= 22) {
    final clip = _drawClip(draw, state);
    final x = _drawShare(draw);
    return EditorAction.frame(FrameAction.setOffset(clip, x, _drawShare(draw)));
  }
  if (choice <= 25) {
    return EditorAction.frame(FrameAction.applyToAll(_drawClip(draw, state)));
  }
  switch (choice) {
    case 26:
      return EditorAction.split;
    case 27:
      final clip = _drawClip(draw, state);
      return EditorAction.moveClip(clip, draw.below(state.project.clips.length + 4) - 1);
    case 28:
      return EditorAction.cutBefore;
    case 29:
      return EditorAction.cutAfter;
    case 30:
      final clip = _drawClip(draw, state);
      return EditorAction.trimStart(clip, _drawAmount(draw));
    case 31:
      final clip = _drawClip(draw, state);
      return EditorAction.trimEnd(clip, _drawAmount(draw));
    case 32:
      return EditorAction.addClips([_added[draw.below(_added.length)]]);
  }
  if (choice <= 36) {
    return EditorAction.select(_drawClip(draw, state));
  }
  return EditorAction.movePlayhead(Time(ticks: draw.below(state.project.duration.ticks + 1)));
}

({double width, double height}) _upright(MediaInfo info) {
  final turned = info.quarterTurns % 2 != 0;
  return (
    width: (turned ? info.height : info.width).toDouble(),
    height: (turned ? info.width : info.height).toDouble(),
  );
}

/// What the state breaks, or null: every zoom from 1 to 4 and every framing equal to itself held.
String? _breach(EditorState state) {
  final project = state.project;
  for (final clip in project.clips) {
    final info = project.media[clip.media];
    if (info == null) {
      return 'clip ${clip.id.raw} has no media facts';
    }
    final framing = clip.framing;
    final name = 'clip ${clip.id.raw} at fit ${framing.fit.rawValue}, backdrop ${framing.backdrop.rawValue}, '
        'zoom ${framing.zoom}, x ${framing.x}, y ${framing.y}';
    if (framing.zoom < 1 || framing.zoom > 4) {
      return '$name: the zoom is outside 1 to 4';
    }
    final side = _upright(info);
    if (framing.held(uprightWidth: side.width, uprightHeight: side.height, canvas: project.canvas) != framing) {
      return '$name: the stored framing is not equal to itself held';
    }
  }
  return null;
}

void main() {
  test('testAThousandRunsOfFiftyActionsKeepEveryFramingHeldAndEveryRectangleByRule84', () {
    final start = EditorState(Seed.twoClips.project);
    final startFault = _breach(start);
    if (startFault != null) {
      fail('the start state of two-clips is not valid: $startFault');
    }
    final counts = <_Kind, int>{};
    for (var startNumber = 1; startNumber <= 1000; startNumber++) {
      final draw = _Draw(startNumber);
      var state = start;
      for (var sent = 1; sent <= 50; sent++) {
        final action = _drawAction(draw, state);
        final next = reduce(state, action);
        for (final kind in _kinds(action, state, next)) {
          counts[kind] = (counts[kind] ?? 0) + 1;
        }
        final fault = _breach(next);
        if (fault != null) {
          fail('start number $startNumber, action $sent of 50: $fault.');
        }
        state = next;
      }
    }
    for (final kind in _Kind.values) {
      expect(counts[kind] ?? 0, greaterThan(0), reason: 'the runs never sent: ${kind.rawValue}');
    }
  });
}
