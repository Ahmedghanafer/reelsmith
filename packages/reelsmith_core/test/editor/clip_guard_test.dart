import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// The check of the plan inside the breach (the clips touch and are as long as the project, by renderPlan) stays in
// Swift.

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

/// The outcomes of the three clip edits. The runs must hold every one.
enum _Kind {
  moveDone('moveClip that changes the order'),
  moveNothing('moveClip to the place the clip has or of an unknown id'),
  cutBeforeDone('cutBefore while canCutBefore is true'),
  cutBeforeRefused('cutBefore while canCutBefore is false'),
  cutAfterDone('cutAfter while canCutAfter is true'),
  cutAfterRefused('cutAfter while canCutAfter is false');

  final String rawValue;

  const _Kind(this.rawValue);
}

bool _sameClips(List<Clip> a, List<Clip> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

_Kind? _kind(EditorAction action, EditorState before, EditorState after) {
  switch (action) {
    case EditorActionMoveClip():
      return _sameClips(after.project.clips, before.project.clips) ? _Kind.moveNothing : _Kind.moveDone;
    case EditorActionCutBefore():
      return before.canCutBefore ? _Kind.cutBeforeDone : _Kind.cutBeforeRefused;
    case EditorActionCutAfter():
      return before.canCutAfter ? _Kind.cutAfterDone : _Kind.cutAfterRefused;
    default:
      return null;
  }
}

/// One time in four an id that no clip has, else the id of a clip of the project, as the merged guards draw.
ClipID _drawClip(_Draw draw, EditorState state) {
  final clips = state.project.clips;
  if (clips.isEmpty || draw.below(4) == 0) {
    return ClipID(state.project.nextClipID + draw.below(3));
  }
  return clips[draw.below(clips.length)].id;
}

/// A place from minus 1 to two past the count, so below the first and past the last too.
int _drawPosition(_Draw draw, EditorState state) => draw.below(state.project.clips.length + 4) - 1;

/// Ten thousand ticks either way are past every limit of a trim, since no media of the runs is that long.
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

Time _drawPlayhead(_Draw draw, EditorState state) {
  final length = state.project.duration.ticks;
  switch (draw.below(6)) {
    case 0:
      return Time(ticks: -1 - draw.below(1000));
    case 1:
      return Time(ticks: length + 1 + draw.below(1000));
    default:
      return Time(ticks: draw.below(length + 1));
  }
}

EditorAction _drawAction(_Draw draw, EditorState state) {
  final choice = draw.below(20);
  if (choice <= 2) {
    final clip = _drawClip(draw, state);
    return EditorAction.moveClip(clip, _drawPosition(draw, state));
  }
  if (choice <= 4) {
    return EditorAction.cutBefore;
  }
  if (choice <= 6) {
    return EditorAction.cutAfter;
  }
  if (choice <= 9) {
    return EditorAction.select(_drawClip(draw, state));
  }
  if (choice == 10) {
    return EditorAction.clearSelection;
  }
  if (choice <= 13) {
    return EditorAction.movePlayhead(_drawPlayhead(draw, state));
  }
  if (choice == 14) {
    return EditorAction.split;
  }
  if (choice == 15) {
    return EditorAction.deleteSelected;
  }
  if (choice <= 17) {
    final clip = _drawClip(draw, state);
    return EditorAction.trimStart(clip, _drawAmount(draw));
  }
  final clip = _drawClip(draw, state);
  return EditorAction.trimEnd(clip, _drawAmount(draw));
}

/// What the state breaks, or null: each clip is at least minimumClip long and inside its media, the ids are unique,
/// every media a clip uses has its facts, and the playhead is a whole frame inside the project.
String? _breach(EditorState state) {
  final project = state.project;
  final ids = <ClipID>{};
  for (final clip in project.clips) {
    if (!ids.add(clip.id)) {
      return 'the clip id ${clip.id.raw} is used twice';
    }
    final info = project.media[clip.media];
    if (info == null) {
      return 'clip ${clip.id.raw} uses the media ${clip.media.raw}, which has no facts';
    }
    if (clip.duration < TimelineGeometry.minimumClip) {
      return 'clip ${clip.id.raw} is ${clip.duration.ticks} ticks long, less than minimumClip';
    }
    if (clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration) {
      return 'clip ${clip.id.raw} starts at ${clip.sourceStart.ticks} and is ${clip.duration.ticks} ticks long '
          'in a media of ${info.duration.ticks}';
    }
  }
  if (state.playhead.ticks.remainder(Time.frame.ticks) != 0 ||
      state.playhead < Time.zero ||
      state.playhead > project.duration) {
    return 'the playhead is at ${state.playhead.ticks} ticks in a project of ${project.duration.ticks}';
  }
  return null;
}

/// A move keeps the same clips, in another order or the same.
String? _moveBreach(EditorState before, EditorAction action, EditorState after) {
  if (action is! EditorActionMoveClip) {
    return null;
  }
  final kept = List.of(before.project.clips)..sort((a, b) => a.id.raw.compareTo(b.id.raw));
  final moved = List.of(after.project.clips)..sort((a, b) => a.id.raw.compareTo(b.id.raw));
  return _sameClips(kept, moved) ? null : 'the move did not keep the same clips';
}

/// Plays 1000 runs of 50 actions from the seed, with the start numbers 1 to 1000, and checks the state after
/// every action. A run starts as a start of the app on the seed does.
void _playRuns(Seed seed, Map<_Kind, int> counts) {
  final start = EditorState(seed.project).copyWith(selectedText: () => seed.selectedText);
  final startFault = _breach(start);
  if (startFault != null) {
    fail('the start state of ${seed.rawValue} is not valid: $startFault');
  }
  for (var startNumber = 1; startNumber <= 1000; startNumber++) {
    final draw = _Draw(startNumber);
    var state = start;
    for (var sent = 1; sent <= 50; sent++) {
      final action = _drawAction(draw, state);
      final next = reduce(state, action);
      final kind = _kind(action, state, next);
      if (kind != null) {
        counts[kind] = (counts[kind] ?? 0) + 1;
      }
      final fault = _breach(next) ?? _moveBreach(state, action, next);
      if (fault != null) {
        fail('seed ${seed.rawValue}, start number $startNumber, action $sent of 50: $fault.');
      }
      state = next;
    }
  }
}

void main() {
  test('testTwoThousandRunsOfFiftyActionsWithTheClipEditsKeepTheClipsValid', () {
    final counts = <_Kind, int>{};
    for (final seed in [Seed.threeClips, Seed.textWide]) {
      _playRuns(seed, counts);
    }
    for (final kind in _Kind.values) {
      expect(counts[kind] ?? 0, greaterThan(0), reason: 'the runs never sent: ${kind.rawValue}');
    }
  });
}
