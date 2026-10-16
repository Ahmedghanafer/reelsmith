import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/text_model_test.dart' show arabicLine;

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

/// The clip actions as they are drawn. The runs must hold every one.
enum _ClipKind {
  addClips('addClips'),
  split('split'),
  trimStart('trimStart of a clip of the project'),
  trimEnd('trimEnd of a clip of the project'),
  trimUnknown('a trim of a clip id that is not in the project'),
  deleteNoText('deleteSelected with no text selected'),
  deleteText('deleteSelected with a text selected'),
  select('select of a clip of the project'),
  selectUnknown('select of a clip id that is not in the project'),
  clearSelection('clearSelection'),
  movePlayhead('movePlayhead'),
  play('play'),
  pause('pause');

  final String rawValue;

  const _ClipKind(this.rawValue);
}

/// The kinds of text actions: each case of TextAction in each of its outcomes (done, held at a limit,
/// unknown id, nothing to do), and the values past a limit or on it. The runs must hold every one.
enum _TextKind {
  add('add on a project with a clip'),
  addOnEmpty('add on an empty project'),
  select('select of a text of the project'),
  selectUnknown('select of a text id that is not in the project'),
  setString('setString of a text of the project'),
  setStringUnknown('setString of a text id that is not in the project'),
  stringEmpty('setString with an empty string'),
  stringSpaces('setString with a string of spaces only'),
  stringLineBreak('setString with a line break'),
  stringArabic('setString with the Arabic line'),
  setStyle('setStyle inside its limits'),
  sizeBelow('setStyle with a size below minimumSize'),
  sizeAbove('setStyle with a size above maximumSize'),
  spacingBelow('setStyle with a line spacing below 0'),
  spacingAbove('setStyle with a line spacing above 2'),
  setStyleUnknown('setStyle of a text id that is not in the project'),
  move('move to a centre inside the canvas'),
  movePastLeft('move to left of the canvas'),
  movePastRight('move to right of the canvas'),
  movePastTop('move to above the canvas'),
  movePastBottom('move to below the canvas'),
  moveOnLeft('move onto the left edge'),
  moveOnRight('move onto the right edge'),
  moveOnTop('move onto the top edge'),
  moveOnBottom('move onto the bottom edge'),
  moveUnknown('move of a text id that is not in the project'),
  turn('turn to an angle inside its limits and more than 3 from 0'),
  turnBelow('turn to below minus 180'),
  turnAbove('turn to above 180'),
  turnNearZero('turn to at most 3 from 0'),
  turnUnknown('turn of a text id that is not in the project'),
  trimStart('trimStart of a text inside its limits'),
  trimStartNegative('trimStart of a text by a negative amount'),
  trimStartPastProject('trimStart of a text to before the start of the project'),
  trimStartPastShortest('trimStart of a text by more than leaves minimumText'),
  trimStartShort('trimStart of a text whose seen range is shorter than minimumText'),
  trimStartNoRange('trimStart of a text with no range'),
  trimStartUnknown('trimStart of a text id that is not in the project'),
  trimEnd('trimEnd of a text inside its limits'),
  trimEndNegative('trimEnd of a text by a negative amount'),
  trimEndPastProject('trimEnd of a text to after the end of the project'),
  trimEndPastShortest('trimEnd of a text by more than leaves minimumText'),
  trimEndShort('trimEnd of a text whose seen range is shorter than minimumText'),
  trimEndNoRange('trimEnd of a text with no range'),
  trimEndUnknown('trimEnd of a text id that is not in the project');

  final String rawValue;

  const _TextKind(this.rawValue);

  /// An action of this kind returns a state equal to the one before it.
  bool get leavesTheStateEqual => switch (this) {
    _TextKind.addOnEmpty ||
    _TextKind.selectUnknown ||
    _TextKind.setStringUnknown ||
    _TextKind.setStyleUnknown ||
    _TextKind.moveUnknown ||
    _TextKind.turnUnknown ||
    _TextKind.trimStartUnknown ||
    _TextKind.trimEndUnknown ||
    _TextKind.trimStartNoRange ||
    _TextKind.trimEndNoRange ||
    _TextKind.trimEndShort => true,
    _ => false,
  };
}

bool _sameList<T>(List<T> a, List<T> b) {
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

/// Swift's Character.isNewline for the scalars the runs draw.
bool _isNewline(int rune) => (rune >= 0x0A && rune <= 0x0D) || rune == 0x85 || rune == 0x2028 || rune == 0x2029;

_ClipKind? _clipKind(EditorAction action, EditorState state) {
  final clips = state.project.clips;
  bool known(ClipID id) => clips.any((clip) => clip.id == id);
  return switch (action) {
    EditorActionAddClips() => _ClipKind.addClips,
    EditorActionSplit() => _ClipKind.split,
    EditorActionTrimStart(:final clip) => known(clip) ? _ClipKind.trimStart : _ClipKind.trimUnknown,
    EditorActionTrimEnd(:final clip) => known(clip) ? _ClipKind.trimEnd : _ClipKind.trimUnknown,
    EditorActionDeleteSelected() => state.selectedText == null ? _ClipKind.deleteNoText : _ClipKind.deleteText,
    EditorActionSelect(:final clip) => known(clip) ? _ClipKind.select : _ClipKind.selectUnknown,
    EditorActionClearSelection() => _ClipKind.clearSelection,
    EditorActionMovePlayhead() => _ClipKind.movePlayhead,
    EditorActionPlay() => _ClipKind.play,
    EditorActionPause() => _ClipKind.pause,
    EditorActionText() => null,
    EditorActionSound() => null,
    EditorActionMoveClip() => null,
    EditorActionCutBefore() => null,
    EditorActionCutAfter() => null,
    EditorActionFrame() => null,
  };
}

List<_TextKind> _textKinds(TextAction action, EditorState state) {
  final project = state.project;
  switch (action) {
    case TextActionAdd():
      return [project.clips.isEmpty ? _TextKind.addOnEmpty : _TextKind.add];
    case TextActionSelect(:final id):
      return [project.text(id) == null ? _TextKind.selectUnknown : _TextKind.select];
    case TextActionSetString(:final id, :final string):
      if (project.text(id) == null) {
        return [_TextKind.setStringUnknown];
      }
      final kinds = [_TextKind.setString];
      if (string.isEmpty) {
        kinds.add(_TextKind.stringEmpty);
      } else if (string.runes.every((rune) => rune == 0x20)) {
        kinds.add(_TextKind.stringSpaces);
      }
      if (string.runes.any(_isNewline)) {
        kinds.add(_TextKind.stringLineBreak);
      }
      if (string == arabicLine()) {
        kinds.add(_TextKind.stringArabic);
      }
      return kinds;
    case TextActionSetStyle(:final id, :final style):
      if (project.text(id) == null) {
        return [_TextKind.setStyleUnknown];
      }
      final past = <(bool, _TextKind)>[
        (style.size < TextGeometry.minimumSize, _TextKind.sizeBelow),
        (style.size > TextGeometry.maximumSize, _TextKind.sizeAbove),
        (style.lineSpacing < 0, _TextKind.spacingBelow),
        (style.lineSpacing > 2, _TextKind.spacingAbove),
      ];
      final kinds = past.where((entry) => entry.$1).map((entry) => entry.$2).toList();
      return kinds.isEmpty ? [_TextKind.setStyle] : kinds;
    case TextActionMove(:final id, :final x, :final y):
      if (project.text(id) == null) {
        return [_TextKind.moveUnknown];
      }
      final width = project.canvas.width.toDouble();
      final height = project.canvas.height.toDouble();
      final past = <(bool, _TextKind)>[
        (x < 0, _TextKind.movePastLeft),
        (x > width, _TextKind.movePastRight),
        (y < 0, _TextKind.movePastTop),
        (y > height, _TextKind.movePastBottom),
      ];
      final edges = <(bool, _TextKind)>[
        (x == 0, _TextKind.moveOnLeft),
        (x == width, _TextKind.moveOnRight),
        (y == 0, _TextKind.moveOnTop),
        (y == height, _TextKind.moveOnBottom),
      ];
      final kinds = past.where((entry) => entry.$1).map((entry) => entry.$2).toList();
      return [
        ...(kinds.isEmpty ? [_TextKind.move] : kinds),
        ...edges.where((entry) => entry.$1).map((entry) => entry.$2),
      ];
    case TextActionTurn(:final id, :final angle):
      if (project.text(id) == null) {
        return [_TextKind.turnUnknown];
      }
      if (angle < -180) {
        return [_TextKind.turnBelow];
      }
      if (angle > 180) {
        return [_TextKind.turnAbove];
      }
      return [angle >= -3 && angle <= 3 ? _TextKind.turnNearZero : _TextKind.turn];
    case TextActionTrimStart(:final id, :final amount):
      if (project.text(id) == null) {
        return [_TextKind.trimStartUnknown];
      }
      final seen = project.range(id);
      if (seen == null) {
        return [_TextKind.trimStartNoRange];
      }
      if (seen.duration < TextGeometry.minimumText) {
        return [_TextKind.trimStartShort];
      }
      final kinds = <_TextKind>[];
      if (amount < Time.zero - seen.start) {
        kinds.add(_TextKind.trimStartPastProject);
      } else if (amount > seen.duration - TextGeometry.minimumText) {
        kinds.add(_TextKind.trimStartPastShortest);
      } else {
        kinds.add(_TextKind.trimStart);
      }
      if (amount < Time.zero) {
        kinds.add(_TextKind.trimStartNegative);
      }
      return kinds;
    case TextActionTrimEnd(:final id, :final amount):
      if (project.text(id) == null) {
        return [_TextKind.trimEndUnknown];
      }
      final seen = project.range(id);
      if (seen == null) {
        return [_TextKind.trimEndNoRange];
      }
      if (seen.duration < TextGeometry.minimumText) {
        return [_TextKind.trimEndShort];
      }
      final kinds = <_TextKind>[];
      if (amount < seen.start + seen.duration - project.duration) {
        kinds.add(_TextKind.trimEndPastProject);
      } else if (amount > seen.duration - TextGeometry.minimumText) {
        kinds.add(_TextKind.trimEndPastShortest);
      } else {
        kinds.add(_TextKind.trimEnd);
      }
      if (amount < Time.zero) {
        kinds.add(_TextKind.trimEndNegative);
      }
      return kinds;
  }
}

/// What addClips is given: the five test clips.
final List<MediaInfo> _pool = TestClip.all.map((clip) => clip.info).toList();

/// What setString is given: an empty string, spaces only, a line break, the Arabic line, and plain words.
final List<String> _strings = ['', '  ', 'one\ntwo', arabicLine(), 'Peace', 'BOX', 'be upon you', 'a b'];

/// One time in four an id that no clip has, else the id of a clip of the project.
ClipID _drawClip(_Draw draw, EditorState state) {
  final clips = state.project.clips;
  if (clips.isEmpty || draw.below(4) == 0) {
    return ClipID(state.project.nextClipID + draw.below(3));
  }
  return clips[draw.below(clips.length)].id;
}

/// One time in eight an id that no text has, else the id of a text of the project.
TextID _drawText(_Draw draw, EditorState state) {
  final texts = state.project.texts;
  if (texts.isEmpty || draw.below(8) == 0) {
    return TextID(state.project.nextTextID + draw.below(3));
  }
  return texts[draw.below(texts.length)].id;
}

/// The amount of a trim, of a clip or of a text. Ten thousand ticks either way are past every limit of a
/// project shorter than that, as each seed is. A project that addClips made longer can hold such an amount
/// inside its limits, and the kind of the action is named from the state, not from the draw. One time in
/// three the amount is at most 60 ticks either way.
Time _drawAmount(_Draw draw) {
  switch (draw.below(6)) {
    case 0:
      return Time(ticks: 10000 + draw.below(40));
    case 1:
      return Time(ticks: -10000 - draw.below(40));
    case 2:
    case 3:
      return Time(ticks: draw.below(121) - 60);
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

/// A size from minus 24 to 1000 and a line spacing from minus 1 to 3, each past a limit one time in three.
TextStyle _drawStyle(_Draw draw) {
  final font = TextFont.allCases[draw.below(TextFont.allCases.length)];
  double size;
  switch (draw.below(6)) {
    case 0:
      size = (15 - draw.below(40)).toDouble();
    case 1:
      size = (401 + draw.below(600)).toDouble();
    default:
      size = (16 + draw.below(385)).toDouble();
  }
  final colour = TextStyle.palette[draw.below(TextStyle.palette.length)];
  final align = TextAlign.allCases[draw.below(TextAlign.allCases.length)];
  double lineSpacing;
  switch (draw.below(6)) {
    case 0:
      lineSpacing = (-1 - draw.below(10)) / 10;
    case 1:
      lineSpacing = 2 + (1 + draw.below(10)) / 10;
    default:
      lineSpacing = draw.below(21) / 10;
  }
  final outline = draw.below(2) == 0;
  final shadow = draw.below(2) == 0;
  final box = draw.below(2) == 0;
  return TextStyle.standard.copyWith(
    font: font,
    size: size,
    colour: colour,
    align: align,
    lineSpacing: lineSpacing,
    outline: outline,
    shadow: shadow,
    box: box,
  );
}

/// One side of a centre on a canvas that many pixels long: before it, after it, on each of its two edges,
/// or inside.
double _drawPlace(_Draw draw, int length) {
  switch (draw.below(8)) {
    case 0:
      return (-1 - draw.below(500)).toDouble();
    case 1:
      return (length + 1 + draw.below(500)).toDouble();
    case 2:
      return 0;
    case 3:
      return length.toDouble();
    default:
      return draw.below(length + 1).toDouble();
  }
}

/// Below minus 180, above 180, at most 3 from 0 in tenths, or a whole angle from minus 179 to 180.
double _drawAngle(_Draw draw) {
  switch (draw.below(6)) {
    case 0:
      return (-181 - draw.below(600)).toDouble();
    case 1:
      return (181 + draw.below(600)).toDouble();
    case 2:
      return (draw.below(61) - 30) / 10;
    default:
      return (draw.below(360) - 179).toDouble();
  }
}

TextAction _drawTextAction(_Draw draw, EditorState state) {
  final canvas = state.project.canvas;
  final choice = draw.below(21);
  if (choice <= 2) {
    return TextAction.add;
  }
  if (choice <= 4) {
    return TextAction.select(_drawText(draw, state));
  }
  if (choice <= 6) {
    final text = _drawText(draw, state);
    return TextAction.setString(text, _strings[draw.below(_strings.length)]);
  }
  if (choice <= 8) {
    final text = _drawText(draw, state);
    return TextAction.setStyle(text, _drawStyle(draw));
  }
  if (choice <= 10) {
    final text = _drawText(draw, state);
    final x = _drawPlace(draw, canvas.width);
    final y = _drawPlace(draw, canvas.height);
    return TextAction.move(text, x, y);
  }
  if (choice <= 12) {
    final text = _drawText(draw, state);
    return TextAction.turn(text, _drawAngle(draw));
  }
  if (choice <= 16) {
    final text = _drawText(draw, state);
    final amount = _drawAmount(draw);
    return TextAction.trimStart(text, amount);
  }
  final text = _drawText(draw, state);
  final amount = _drawAmount(draw);
  return TextAction.trimEnd(text, amount);
}

/// 22 times in 47 a clip action, else a text action.
EditorAction _drawAction(_Draw draw, EditorState state) {
  final choice = draw.below(47);
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
  if (choice <= 5) {
    final clip = _drawClip(draw, state);
    final amount = _drawAmount(draw);
    return EditorAction.trimStart(clip, amount);
  }
  if (choice <= 8) {
    final clip = _drawClip(draw, state);
    final amount = _drawAmount(draw);
    return EditorAction.trimEnd(clip, amount);
  }
  if (choice <= 11) {
    return EditorAction.deleteSelected;
  }
  if (choice <= 15) {
    return EditorAction.select(_drawClip(draw, state));
  }
  if (choice == 16) {
    return EditorAction.clearSelection;
  }
  if (choice <= 19) {
    return EditorAction.movePlayhead(_drawPlayhead(draw, state));
  }
  if (choice == 20) {
    return EditorAction.play;
  }
  if (choice == 21) {
    return EditorAction.pause;
  }
  return EditorAction.text(_drawTextAction(draw, state));
}

/// The valid state that `reduce` must keep. For the clips: "A state is valid when every clip lies inside its
/// source, every clip length is a whole number of frames and at least `minimumClip`, the playhead is a whole
/// frame from zero to the project length, and the selection is a clip of the project or none." For the texts:
/// "every text id is used once, every `.range` starts at a whole frame not below zero and is a whole number of
/// frames of at least `minimumText`, every size lies between the two limits, every centre lies inside the
/// canvas, every rotation is above minus 180 and at most 180, `selectedText` is a text of the project or nil,
/// at most one selection is set, and a blank text exists only while it is selected."
/// Answers the first part of those sentences the state breaks, or null for a valid state.
String? _breach(EditorState state) {
  final project = state.project;
  final frame = Time.frame.ticks;
  for (final clip in project.clips) {
    final info = project.media[clip.media];
    if (info == null) {
      return 'clip ${clip.id.raw} has no media facts, so no source to lie inside';
    }
    if (clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration) {
      return 'clip ${clip.id.raw} lies outside its source: it starts at ${clip.sourceStart.ticks} and is '
          '${clip.duration.ticks} ticks long in a source of ${info.duration.ticks}';
    }
    if (clip.duration.ticks.remainder(frame) != 0 || clip.duration < TimelineGeometry.minimumClip) {
      return 'the length of clip ${clip.id.raw} is ${clip.duration.ticks} ticks';
    }
  }
  if (state.playhead.ticks.remainder(frame) != 0 ||
      state.playhead < Time.zero ||
      state.playhead > project.duration) {
    return 'the playhead is at ${state.playhead.ticks} ticks in a project of ${project.duration.ticks}';
  }
  final selection = state.selection;
  if (selection != null && !project.clips.any((clip) => clip.id == selection)) {
    return 'the selection is clip ${selection.raw}, which is not in the project';
  }
  final width = project.canvas.width.toDouble();
  final height = project.canvas.height.toDouble();
  final ids = <TextID>{};
  for (final text in project.texts) {
    if (!ids.add(text.id)) {
      return 'the text id ${text.id.raw} is used twice';
    }
    final span = text.span;
    if (span is TextSpanRange) {
      final range = span.range;
      if (range.start < Time.zero || range.start.ticks.remainder(frame) != 0) {
        return 'the range of text ${text.id.raw} starts at ${range.start.ticks} ticks';
      }
      if (range.duration.ticks.remainder(frame) != 0 || range.duration < TextGeometry.minimumText) {
        return 'the range of text ${text.id.raw} is ${range.duration.ticks} ticks long';
      }
    }
    if (!(text.style.size >= TextGeometry.minimumSize && text.style.size <= TextGeometry.maximumSize)) {
      return 'the size of text ${text.id.raw} is ${text.style.size}, outside its two limits';
    }
    if (!(text.x >= 0 && text.x <= width && text.y >= 0 && text.y <= height)) {
      return 'the centre of text ${text.id.raw} is ${text.x}, ${text.y}, outside the canvas';
    }
    if (!(text.rotation > -180 && text.rotation <= 180)) {
      return 'the rotation of text ${text.id.raw} is ${text.rotation}';
    }
    if (text.isBlank && state.selectedText != text.id) {
      return 'text ${text.id.raw} is blank and not selected';
    }
  }
  final selected = state.selectedText;
  if (selected != null && project.text(selected) == null) {
    return 'the selected text is ${selected.raw}, which is not in the project';
  }
  if (state.selection != null && state.selectedText != null) {
    return 'a clip and a text are both selected';
  }
  return null;
}

/// What is wrong with `textInfo` of the state, or null.
String? _infoBreach(EditorState state) {
  final info = state.textInfo;
  final selected = state.selectedText;
  if (selected == null) {
    return info == 'none' ? null : 'no text is selected and textInfo is $info';
  }
  final fields = info.split(' ');
  if (fields.length != 10 || fields.any((field) => field.isEmpty)) {
    return 'a text is selected and textInfo is not ten fields with one space between them: $info';
  }
  if ((fields[8] == 'hidden') != (state.project.range(selected) == null)) {
    return 'the ninth field of textInfo is ${fields[8]}, against the range of the selected text';
  }
  return null;
}

/// What the action did that its kind must not do, or null. The highest is that of the text ids seen in the run
/// before the action.
String? _editBreach(EditorState before, EditorAction action, EditorState after, int highest) {
  if (action is EditorActionText) {
    if (action.textAction is TextActionAdd && before.canAddText) {
      final given = after.selectedText;
      if (given == null || given.raw <= highest) {
        return 'add did not give an id higher than $highest, the highest text id seen in the run';
      }
    }
    return null;
  }
  final selected = before.selectedText;
  if (action is EditorActionDeleteSelected && selected != null) {
    if (!before.canDelete) {
      return 'a text was selected and canDelete was false';
    }
    if (!_sameList(after.project.texts, before.project.texts.where((text) => text.id != selected).toList())) {
      return 'deleteSelected with text ${selected.raw} selected did not remove exactly that text';
    }
    if (!_sameList(after.project.clips, before.project.clips)) {
      return 'deleteSelected with a text selected changed the clips';
    }
    return null;
  }
  // A clip action. A blank text that lost its selection is gone, and no other text differs.
  final kept = before.project.texts
      .where((text) => !(text.isBlank && text.id == before.selectedText && text.id != after.selectedText))
      .toList();
  if (!_sameList(after.project.texts, kept)) {
    return 'a clip action changed the texts';
  }
  return null;
}

int _highestTextID(EditorState state) =>
    state.project.texts.fold(0, (highest, text) => text.id.raw > highest ? text.id.raw : highest);

/// Plays 1000 runs of 50 actions from the seed, with the start numbers 1 to 1000, and checks the state after
/// every action. A text seed starts with its text selected, as a start of the app on it does. Counts how often
/// each kind of action was drawn. Fails the test at the first fault.
void _playRuns(Seed seed, Map<String, int> counts) {
  final start = EditorState(seed.project).copyWith(selectedText: () => seed.selectedText);
  final startFault = _breach(start);
  if (startFault != null) {
    fail('the start state of ${seed.rawValue} is not valid: $startFault');
  }
  for (var startNumber = 1; startNumber <= 1000; startNumber++) {
    final draw = _Draw(startNumber);
    var state = start;
    var highest = _highestTextID(state);
    for (var sent = 1; sent <= 50; sent++) {
      final action = _drawAction(draw, state);
      var mustStayEqual = false;
      if (action is EditorActionText) {
        for (final kind in _textKinds(action.textAction, state)) {
          counts[kind.rawValue] = (counts[kind.rawValue] ?? 0) + 1;
          mustStayEqual = mustStayEqual || kind.leavesTheStateEqual;
        }
      } else {
        final kind = _clipKind(action, state);
        if (kind != null) {
          counts[kind.rawValue] = (counts[kind.rawValue] ?? 0) + 1;
        }
      }
      final next = reduce(state, action);
      var fault = _breach(next) ?? _infoBreach(next);
      fault ??= _editBreach(state, action, next, highest);
      if (fault == null && mustStayEqual && next != state) {
        fault = 'the action had nothing to do and the state is not equal to the one before it';
      }
      if (fault != null) {
        fail('seed ${seed.rawValue}, start number $startNumber, action $sent of 50: $fault.');
      }
      final seen = _highestTextID(next);
      if (seen > highest) {
        highest = seen;
      }
      state = next;
    }
  }
}

void main() {
  test('testThreeThousandRunsOfFiftyClipAndTextActionsKeepTheStateValidAndThePlanInsideTheProject', () {
    final counts = <String, int>{};
    for (final seed in [Seed.textWide, Seed.textBoxWide, Seed.threeClips]) {
      _playRuns(seed, counts);
    }
    final kinds = [..._ClipKind.values.map((kind) => kind.rawValue), ..._TextKind.values.map((kind) => kind.rawValue)];
    for (final kind in kinds) {
      expect(counts[kind] ?? 0, greaterThan(0), reason: 'the runs never drew: $kind');
    }
  });
}
