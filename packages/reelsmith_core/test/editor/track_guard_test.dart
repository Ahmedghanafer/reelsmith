import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// The check of the plan, planBreach, stays in Swift: it reads renderPlan.

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

MediaInfo _media(String name, int ticks) => MediaInfo(
  id: MediaID(name),
  fileName: '$name.mov',
  width: 1080,
  height: 1920,
  duration: Time(ticks: ticks),
  quarterTurns: 0,
  hasSound: true,
);

final _oddA = _media('odd-a', 1219);
final _oddB = _media('odd-b', 2417);

/// What addClips is given: the five test clips, two lengths that are not whole frames, one shorter than
/// the shortest clip, and red once more with other facts.
final List<MediaInfo> _pool = [
  ...TestClip.all.map((clip) => clip.info),
  _oddA,
  _oddB,
  _media('short', 59),
  _media('red', 1200),
];

/// What an action is to the state it is sent to. The runs from the three clip seed must hold every one.
enum _Kind {
  add('addClips'),
  addTooShort('addClips with a media shorter than minimumClip'),
  splitAllowed('split while canSplit is true'),
  splitRefused('split while canSplit is false'),
  trimStartInside('trimStart inside its limits'),
  trimStartPastShortest('trimStart by more than leaves minimumClip'),
  trimStartPastSource('trimStart to before the start of the source'),
  trimStartUnknown('trimStart of a clip id that is not in the project'),
  trimEndInside('trimEnd inside its limits'),
  trimEndPastShortest('trimEnd by more than leaves minimumClip'),
  trimEndPastSource('trimEnd to after the end of the source'),
  trimEndUnknown('trimEnd of a clip id that is not in the project'),
  deleteAllowed('deleteSelected while canDelete is true'),
  deleteRefused('deleteSelected while canDelete is false'),
  selectKnown('select of a clip of the project'),
  selectUnknown('select of a clip id that is not in the project'),
  clearSelection('clearSelection'),
  moveInside('movePlayhead inside the project'),
  moveBelowZero('movePlayhead to below zero'),
  movePastEnd('movePlayhead to past the project length'),
  play('play'),
  pause('pause'),
  becameEmpty('an action that left the project empty');

  final String rawValue;

  const _Kind(this.rawValue);
}

Clip? _clipOf(Project project, ClipID id) {
  for (final clip in project.clips) {
    if (clip.id == id) {
      return clip;
    }
  }
  return null;
}

_Kind _kind(EditorAction action, EditorState state) {
  final project = state.project;
  switch (action) {
    case EditorActionAddClips(:final media):
      final tooShort = media.any((given) => given.duration.roundedDownToFrame < TimelineGeometry.minimumClip);
      return tooShort ? _Kind.addTooShort : _Kind.add;
    case EditorActionSplit():
      return state.canSplit ? _Kind.splitAllowed : _Kind.splitRefused;
    case EditorActionTrimStart(:final clip, :final amount):
      final found = _clipOf(project, clip);
      if (found == null) {
        return _Kind.trimStartUnknown;
      }
      if (amount > found.duration - TimelineGeometry.minimumClip) {
        return _Kind.trimStartPastShortest;
      }
      return amount < Time.zero - found.sourceStart ? _Kind.trimStartPastSource : _Kind.trimStartInside;
    case EditorActionTrimEnd(:final clip, :final amount):
      final found = _clipOf(project, clip);
      final info = found == null ? null : project.media[found.media];
      if (found == null || info == null) {
        return _Kind.trimEndUnknown;
      }
      if (amount > found.duration - TimelineGeometry.minimumClip) {
        return _Kind.trimEndPastShortest;
      }
      return amount < found.sourceStart + found.duration - info.duration
          ? _Kind.trimEndPastSource
          : _Kind.trimEndInside;
    case EditorActionDeleteSelected():
      return state.canDelete ? _Kind.deleteAllowed : _Kind.deleteRefused;
    case EditorActionSelect(:final clip):
      return _clipOf(project, clip) != null ? _Kind.selectKnown : _Kind.selectUnknown;
    case EditorActionClearSelection():
      return _Kind.clearSelection;
    case EditorActionMovePlayhead(:final time):
      if (time < Time.zero) {
        return _Kind.moveBelowZero;
      }
      return time > project.duration ? _Kind.movePastEnd : _Kind.moveInside;
    case EditorActionPlay():
      return _Kind.play;
    case EditorActionPause():
      return _Kind.pause;
    case EditorActionText():
      return _Kind.clearSelection;
    case EditorActionSound():
      return _Kind.clearSelection;
    case EditorActionMoveClip():
      return _Kind.clearSelection;
    case EditorActionCutBefore():
      return _Kind.clearSelection;
    case EditorActionCutAfter():
      return _Kind.clearSelection;
    case EditorActionFrame():
      return _Kind.clearSelection;
  }
}

/// One time in four an id that no clip has, else the id of a clip of the project.
ClipID _drawClip(_Draw draw, EditorState state) {
  final clips = state.project.clips;
  if (clips.isEmpty || draw.below(4) == 0) {
    return ClipID(state.project.nextClipID + draw.below(3));
  }
  return clips[draw.below(clips.length)].id;
}

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
  final choice = draw.below(19);
  if (choice == 0) {
    final given = <MediaInfo>[];
    final count = draw.below(3);
    for (var index = 0; index < count; index++) {
      given.add(_pool[draw.below(_pool.length)]);
    }
    return EditorAction.addClips(given);
  }
  if (choice <= 2) {
    return EditorAction.split;
  }
  if (choice <= 4) {
    final clip = _drawClip(draw, state);
    final amount = _drawAmount(draw);
    return EditorAction.trimStart(clip, amount);
  }
  if (choice <= 6) {
    final clip = _drawClip(draw, state);
    final amount = _drawAmount(draw);
    return EditorAction.trimEnd(clip, amount);
  }
  if (choice <= 9) {
    return EditorAction.deleteSelected;
  }
  if (choice <= 12) {
    return EditorAction.select(_drawClip(draw, state));
  }
  if (choice == 13) {
    return EditorAction.clearSelection;
  }
  if (choice <= 16) {
    return EditorAction.movePlayhead(_drawPlayhead(draw, state));
  }
  if (choice == 17) {
    return EditorAction.play;
  }
  return EditorAction.pause;
}

/// The valid state that `reduce` must keep: "A state is valid when every clip lies inside its source, every
/// clip length is a whole number of frames and at least `minimumClip`, the playhead is a whole frame from zero
/// to the project length, and the selection is a clip of the project or none."
/// Answers the first part of that sentence the state breaks, or null for a valid state.
String? _breach(EditorState state) {
  for (final clip in state.project.clips) {
    final info = state.project.media[clip.media];
    if (info == null) {
      return 'clip ${clip.id.raw} has no media facts, so no source to lie inside';
    }
    if (clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration) {
      return 'clip ${clip.id.raw} lies outside its source: it starts at ${clip.sourceStart.ticks} and is '
          '${clip.duration.ticks} ticks long in a source of ${info.duration.ticks}';
    }
    if (clip.duration.ticks.remainder(Time.frame.ticks) != 0) {
      return 'the length of clip ${clip.id.raw} is ${clip.duration.ticks} ticks, not a whole number of frames';
    }
    if (clip.duration < TimelineGeometry.minimumClip) {
      return 'the length of clip ${clip.id.raw} is ${clip.duration.ticks} ticks, less than minimumClip';
    }
  }
  if (state.playhead.ticks.remainder(Time.frame.ticks) != 0) {
    return 'the playhead is at ${state.playhead.ticks} ticks, not a whole frame';
  }
  if (state.playhead < Time.zero || state.playhead > state.project.duration) {
    return 'the playhead is at ${state.playhead.ticks} ticks in a project of ${state.project.duration.ticks}';
  }
  final selection = state.selection;
  if (selection != null && _clipOf(state.project, selection) == null) {
    return 'the selection is clip ${selection.raw}, which is not in the project';
  }
  return null;
}

/// A split or a delete that could be done must change the state, and one that could not must leave it equal.
String? _gateBreach(EditorState before, EditorAction action, EditorState after) {
  final bool allowed;
  final String name;
  switch (action) {
    case EditorActionSplit():
      allowed = before.canSplit;
      name = 'canSplit';
    case EditorActionDeleteSelected():
      allowed = before.canDelete;
      name = 'canDelete';
    default:
      return null;
  }
  if (allowed && after == before) {
    return '$name was true and the action changed nothing';
  }
  if (!allowed && after != before) {
    return '$name was false and the action changed the state';
  }
  return null;
}

/// Plays 1000 runs of 50 actions from the start state, with the start numbers 1 to 1000, and checks the state
/// after every action. Answers how often each kind of action was sent, or null after a failure.
Map<_Kind, int>? _playRuns(EditorState start) {
  final startFault = _breach(start);
  if (startFault != null) {
    fail('the start state is not valid: $startFault');
  }
  final counts = <_Kind, int>{};
  for (var startNumber = 1; startNumber <= 1000; startNumber++) {
    final draw = _Draw(startNumber);
    var state = start;
    for (var sent = 1; sent <= 50; sent++) {
      final action = _drawAction(draw, state);
      final kind = _kind(action, state);
      counts[kind] = (counts[kind] ?? 0) + 1;
      final next = reduce(state, action);
      final fault = _breach(next) ?? _gateBreach(state, action, next);
      if (fault != null) {
        fail('start number $startNumber, action $sent of 50: $fault.');
      }
      if (next.project.clips.isEmpty && state.project.clips.isNotEmpty) {
        counts[_Kind.becameEmpty] = (counts[_Kind.becameEmpty] ?? 0) + 1;
      }
      state = next;
    }
  }
  return counts;
}

void main() {
  const red = ClipID(2);
  final threeClips = EditorState(Seed.threeClips.project);

  test('testAThousandRunsOfFiftyActionsFromThreeClipsKeepTheStateValidAndThePlanAsLongAsTheProject', () {
    final counts = _playRuns(threeClips);
    if (counts == null) {
      return;
    }
    for (final kind in _Kind.values) {
      expect(counts[kind] ?? 0, greaterThan(0), reason: 'the runs never sent: ${kind.rawValue}');
    }
  });

  test('testTheSameRunsFromMediaWhoseLengthsAreNotWholeFramesKeepTheStateValid', () {
    final project = const Project().copyWith(
      media: {_oddA.id: _oddA, _oddB.id: _oddB},
      clips: [
        Clip(id: const ClipID(1), media: _oddA.id, sourceStart: Time.zero, duration: const Time(ticks: 1200)),
        Clip(id: const ClipID(2), media: _oddB.id, sourceStart: Time.zero, duration: const Time(ticks: 2400)),
      ],
      nextClipID: 3,
    );

    expect(_playRuns(EditorState(project)), isNotNull);
  });

  test('testATrimOfAnEarlierClipLeavesThePlayheadAtItsTimelineTime', () {
    final state = threeClips.copyWith(playhead: const Time(ticks: 4200));

    final endTrimmed = reduce(state, EditorAction.trimEnd(red, const Time(ticks: 600)));
    final startTrimmed = reduce(state, EditorAction.trimStart(red, const Time(ticks: 600)));

    expect(endTrimmed.project.duration, const Time(ticks: 4800));
    expect(endTrimmed.playhead, const Time(ticks: 4200));
    expect(startTrimmed.project.duration, const Time(ticks: 4800));
    expect(startTrimmed.playhead, const Time(ticks: 4200));
  });

  test('testATrimEndThatChangesNothingStillPausesAPlayingState', () {
    final playing = threeClips.copyWith(isPlaying: true);

    expect(reduce(playing, EditorAction.trimEnd(red, const Time(ticks: 19))), threeClips);
  });
}
