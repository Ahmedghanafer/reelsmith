import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/sound_model_test.dart' show musicFile;

// The check of the plan, planFault, stays in Swift: it reads renderPlan.

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

/// The cases of EditorAction and of TextAction. The runs must send every one. The case sound is counted by
/// the kinds of sound actions.
enum _ActionCase {
  addClips('addClips'),
  split('split'),
  trimStart('trimStart'),
  trimEnd('trimEnd'),
  deleteSelected('deleteSelected'),
  select('select'),
  clearSelection('clearSelection'),
  movePlayhead('movePlayhead'),
  play('play'),
  pause('pause'),
  textAdd('text add'),
  textSelect('text select'),
  textSetString('text setString'),
  textSetStyle('text setStyle'),
  textMove('text move'),
  textTurn('text turn'),
  textTrimStart('text trimStart'),
  textTrimEnd('text trimEnd');

  final String rawValue;

  const _ActionCase(this.rawValue);
}

/// The kinds of sound actions: each case of SoundAction in each of its outcomes (done, held at a limit,
/// nothing to do), and the values past a limit. The runs must draw every one.
enum _SoundKind {
  open('open on a project with a clip'),
  openEmpty('open on an empty project'),
  clipVolume('setClipVolume from 0 to 1 to another value'),
  clipVolumeBelow('setClipVolume below 0'),
  clipVolumeAbove('setClipVolume above 1'),
  clipVolumeNotFinite('setClipVolume with a number that is not finite'),
  clipVolumeSame('setClipVolume with the value the project has'),
  mute('muteClips to the other value'),
  muteSame('muteClips with the value the project has'),
  setMusicLong('setMusic with long-tone'),
  setMusicShort('setMusic with short-tone'),
  setMusic500('setMusic with a file of 500 ticks'),
  setMusic900('setMusic with a file of 900 ticks'),
  setMusicNoLength('setMusic with a file of no length'),
  setMusicSame('setMusic with the music the project has'),
  removeMusic('removeMusic with music'),
  removeNoMusic('removeMusic with no music'),
  musicVolume('setMusicVolume from 0 to 1 to another value'),
  musicVolumeBelow('setMusicVolume below 0'),
  musicVolumeAbove('setMusicVolume above 1'),
  musicVolumeNotFinite('setMusicVolume with a number that is not finite'),
  musicVolumeSame('setMusicVolume with the value the project has'),
  musicVolumeNoMusic('setMusicVolume with no music'),
  start('setMusicStart to another whole frame inside its limits'),
  startBelow('setMusicStart below zero'),
  startAbove('setMusicStart above the largest start'),
  startOffFrame('setMusicStart inside its limits and not on a whole frame'),
  startSame('setMusicStart with the value the project has'),
  startNoMusic('setMusicStart with no music'),
  fadeIn('setFadeIn to another whole frame inside its limits'),
  fadeInBelow('setFadeIn below zero'),
  fadeInAbove('setFadeIn above 3000'),
  fadeInOffFrame('setFadeIn inside its limits and not on a whole frame'),
  fadeInSame('setFadeIn with the value the project has'),
  fadeInNoMusic('setFadeIn with no music'),
  fadeOut('setFadeOut to another whole frame inside its limits'),
  fadeOutBelow('setFadeOut below zero'),
  fadeOutAbove('setFadeOut above 3000'),
  fadeOutOffFrame('setFadeOut inside its limits and not on a whole frame'),
  fadeOutSame('setFadeOut with the value the project has'),
  fadeOutNoMusic('setFadeOut with no music');

  final String rawValue;

  const _SoundKind(this.rawValue);

  /// An action of this kind returns a state equal to the one before it.
  bool get leavesTheStateEqual => switch (this) {
    _SoundKind.openEmpty ||
    _SoundKind.clipVolumeNotFinite ||
    _SoundKind.clipVolumeSame ||
    _SoundKind.muteSame ||
    _SoundKind.setMusicNoLength ||
    _SoundKind.setMusicSame ||
    _SoundKind.removeNoMusic ||
    _SoundKind.musicVolumeNotFinite ||
    _SoundKind.musicVolumeSame ||
    _SoundKind.musicVolumeNoMusic ||
    _SoundKind.startSame ||
    _SoundKind.startNoMusic ||
    _SoundKind.fadeInSame ||
    _SoundKind.fadeInNoMusic ||
    _SoundKind.fadeOutSame ||
    _SoundKind.fadeOutNoMusic => true,
    _ => false,
  };
}

_ActionCase? _actionCase(EditorAction action) => switch (action) {
  EditorActionAddClips() => _ActionCase.addClips,
  EditorActionSplit() => _ActionCase.split,
  EditorActionTrimStart() => _ActionCase.trimStart,
  EditorActionTrimEnd() => _ActionCase.trimEnd,
  EditorActionDeleteSelected() => _ActionCase.deleteSelected,
  EditorActionSelect() => _ActionCase.select,
  EditorActionClearSelection() => _ActionCase.clearSelection,
  EditorActionMovePlayhead() => _ActionCase.movePlayhead,
  EditorActionPlay() => _ActionCase.play,
  EditorActionPause() => _ActionCase.pause,
  EditorActionText(:final textAction) => switch (textAction) {
    TextActionAdd() => _ActionCase.textAdd,
    TextActionSelect() => _ActionCase.textSelect,
    TextActionSetString() => _ActionCase.textSetString,
    TextActionSetStyle() => _ActionCase.textSetStyle,
    TextActionMove() => _ActionCase.textMove,
    TextActionTurn() => _ActionCase.textTurn,
    TextActionTrimStart() => _ActionCase.textTrimStart,
    TextActionTrimEnd() => _ActionCase.textTrimEnd,
  },
  EditorActionSound() => null,
  EditorActionMoveClip() => null,
  EditorActionCutBefore() => null,
  EditorActionCutAfter() => null,
  EditorActionFrame() => null,
};

/// The kind of a volume sent: not finite, the value stored, below 0, above 1, or another value inside.
_SoundKind _volumeKind(
  double volume,
  double stored,
  ({_SoundKind notFinite, _SoundKind same, _SoundKind below, _SoundKind above, _SoundKind done}) kinds,
) {
  if (!volume.isFinite) {
    return kinds.notFinite;
  }
  if (volume == stored) {
    return kinds.same;
  }
  if (volume < 0) {
    return kinds.below;
  }
  return volume > 1 ? kinds.above : kinds.done;
}

/// The kind of a time sent: the value stored, below zero, above the upper limit, inside and not on a whole
/// frame, or another whole frame inside.
_SoundKind _timeKind(
  Time time,
  Time stored,
  Time upper,
  ({_SoundKind same, _SoundKind below, _SoundKind above, _SoundKind offFrame, _SoundKind done}) kinds,
) {
  if (time == stored) {
    return kinds.same;
  }
  if (time < Time.zero) {
    return kinds.below;
  }
  if (time > upper) {
    return kinds.above;
  }
  return time.ticks.remainder(Time.frame.ticks) != 0 ? kinds.offFrame : kinds.done;
}

_SoundKind _soundKind(SoundAction action, EditorState state) {
  final project = state.project;
  final music = project.music;
  switch (action) {
    case SoundActionOpen():
      return project.clips.isEmpty ? _SoundKind.openEmpty : _SoundKind.open;
    case SoundActionSetClipVolume(:final volume):
      return _volumeKind(volume, project.clipVolume, (
        notFinite: _SoundKind.clipVolumeNotFinite,
        same: _SoundKind.clipVolumeSame,
        below: _SoundKind.clipVolumeBelow,
        above: _SoundKind.clipVolumeAbove,
        done: _SoundKind.clipVolume,
      ));
    case SoundActionMuteClips(:final muted):
      return muted == project.clipsMuted ? _SoundKind.muteSame : _SoundKind.mute;
    case SoundActionSetMusic(:final file):
      if (file.duration <= Time.zero) {
        return _SoundKind.setMusicNoLength;
      }
      if (project.music == Music.file(file)) {
        return _SoundKind.setMusicSame;
      }
      if (file == TestTone.long.file) {
        return _SoundKind.setMusicLong;
      }
      if (file == TestTone.short.file) {
        return _SoundKind.setMusicShort;
      }
      return file.duration.ticks == 500 ? _SoundKind.setMusic500 : _SoundKind.setMusic900;
    case SoundActionRemoveMusic():
      return music == null ? _SoundKind.removeNoMusic : _SoundKind.removeMusic;
    case SoundActionSetMusicVolume(:final volume):
      if (music == null) {
        return _SoundKind.musicVolumeNoMusic;
      }
      return _volumeKind(volume, music.volume, (
        notFinite: _SoundKind.musicVolumeNotFinite,
        same: _SoundKind.musicVolumeSame,
        below: _SoundKind.musicVolumeBelow,
        above: _SoundKind.musicVolumeAbove,
        done: _SoundKind.musicVolume,
      ));
    case SoundActionSetMusicStart(:final start):
      if (music == null) {
        return _SoundKind.startNoMusic;
      }
      return _timeKind(start, music.start, music.largestStart, (
        same: _SoundKind.startSame,
        below: _SoundKind.startBelow,
        above: _SoundKind.startAbove,
        offFrame: _SoundKind.startOffFrame,
        done: _SoundKind.start,
      ));
    case SoundActionSetFadeIn(:final fade):
      if (music == null) {
        return _SoundKind.fadeInNoMusic;
      }
      return _timeKind(fade, music.fadeIn, SoundGeometry.maximumFade, (
        same: _SoundKind.fadeInSame,
        below: _SoundKind.fadeInBelow,
        above: _SoundKind.fadeInAbove,
        offFrame: _SoundKind.fadeInOffFrame,
        done: _SoundKind.fadeIn,
      ));
    case SoundActionSetFadeOut(:final fade):
      if (music == null) {
        return _SoundKind.fadeOutNoMusic;
      }
      return _timeKind(fade, music.fadeOut, SoundGeometry.maximumFade, (
        same: _SoundKind.fadeOutSame,
        below: _SoundKind.fadeOutBelow,
        above: _SoundKind.fadeOutAbove,
        offFrame: _SoundKind.fadeOutOffFrame,
        done: _SoundKind.fadeOut,
      ));
    case SoundActionSetVolumeOfClip():
      throw StateError('the runs draw no volume of a clip');
  }
}

/// What addClips is given: the five test clips.
final List<MediaInfo> _pool = TestClip.all.map((clip) => clip.info).toList();

/// What setString is given: an empty string, spaces only, and plain words.
const List<String> _strings = ['', '  ', 'Peace', 'a b'];

/// What setMusic is given: the two test tones, a file shorter than minimumMusic, a file whose largest start
/// is shorter than one step, and a file with no length.
final List<MusicFile> _musicFiles = [
  TestTone.long.file,
  TestTone.short.file,
  musicFile(500),
  musicFile(900),
  musicFile(0),
];

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

/// The amount of a trim, of a clip or of a text: ten thousand ticks either way, at most 60 ticks either way,
/// or at most 800 ticks either way.
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

/// Below 0 down to minus 2, above 1 up to 3, a number that is not finite, the value stored, or a step of
/// 0.05 from 0 to 1.
double _drawVolume(_Draw draw, double stored) {
  switch (draw.below(8)) {
    case 0:
      return -(1 + draw.below(200)) / 100;
    case 1:
      return 1 + (1 + draw.below(200)) / 100;
    case 2:
      return [double.nan, double.infinity, double.negativeInfinity][draw.below(3)];
    case 3:
      return stored;
    default:
      return draw.below(21) / 20;
  }
}

/// Below zero, above the upper limit, inside and not on a whole frame, the value stored, or a whole frame
/// from zero to the upper limit. With an upper limit of zero, the time not on a whole frame is above it.
Time _drawTime(_Draw draw, Time stored, Time upper) {
  final frames = upper.ticks ~/ Time.frame.ticks;
  switch (draw.below(8)) {
    case 0:
      return Time(ticks: -1 - draw.below(1000));
    case 1:
      return Time(ticks: upper.ticks + 1 + draw.below(2000));
    case 2:
      final frame = draw.below(frames > 1 ? frames : 1);
      return Time(ticks: frame * Time.frame.ticks + 1 + draw.below(19));
    case 3:
      return stored;
    default:
      return Time(ticks: draw.below(frames + 1) * Time.frame.ticks);
  }
}

TextAction _drawTextAction(_Draw draw, EditorState state) {
  final canvas = state.project.canvas;
  switch (draw.below(8)) {
    case 0:
      return TextAction.add;
    case 1:
      return TextAction.select(_drawText(draw, state));
    case 2:
      final text = _drawText(draw, state);
      return TextAction.setString(text, _strings[draw.below(_strings.length)]);
    case 3:
      final text = _drawText(draw, state);
      final style = TextStyle.standard.copyWith(size: draw.below(500).toDouble());
      return TextAction.setStyle(text, style);
    case 4:
      final text = _drawText(draw, state);
      final x = (draw.below(canvas.width + 201) - 100).toDouble();
      final y = (draw.below(canvas.height + 201) - 100).toDouble();
      return TextAction.move(text, x, y);
    case 5:
      final text = _drawText(draw, state);
      return TextAction.turn(text, (draw.below(721) - 360).toDouble());
    case 6:
      final text = _drawText(draw, state);
      final amount = _drawAmount(draw);
      return TextAction.trimStart(text, amount);
    default:
      final text = _drawText(draw, state);
      final amount = _drawAmount(draw);
      return TextAction.trimEnd(text, amount);
  }
}

SoundAction _drawSoundAction(_Draw draw, EditorState state) {
  final project = state.project;
  final music = project.music;
  switch (draw.below(12)) {
    case 0:
    case 1:
      return SoundAction.open;
    case 2:
      return SoundAction.setClipVolume(_drawVolume(draw, project.clipVolume));
    case 3:
      return SoundAction.muteClips(draw.below(2) == 0);
    case 4:
    case 5:
      return SoundAction.setMusic(_musicFiles[draw.below(_musicFiles.length)]);
    case 6:
      return SoundAction.removeMusic;
    case 7:
      return SoundAction.setMusicVolume(_drawVolume(draw, music?.volume ?? 1));
    case 8:
    case 9:
      final upper = music?.largestStart ?? SoundGeometry.maximumFade;
      return SoundAction.setMusicStart(_drawTime(draw, music?.start ?? Time.zero, upper));
    case 10:
      final fade = _drawTime(draw, music?.fadeIn ?? Time.zero, SoundGeometry.maximumFade);
      return SoundAction.setFadeIn(fade);
    default:
      final fade = _drawTime(draw, music?.fadeOut ?? Time.zero, SoundGeometry.maximumFade);
      return SoundAction.setFadeOut(fade);
  }
}

/// 21 times in 50 a clip action, 9 times a text action and 20 times a sound action.
EditorAction _drawAction(_Draw draw, EditorState state) {
  final choice = draw.below(50);
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
  if (choice <= 18) {
    return EditorAction.movePlayhead(_drawPlayhead(draw, state));
  }
  if (choice == 19) {
    return EditorAction.play;
  }
  if (choice == 20) {
    return EditorAction.pause;
  }
  if (choice <= 29) {
    return EditorAction.text(_drawTextAction(draw, state));
  }
  return EditorAction.sound(_drawSoundAction(draw, state));
}

/// A broken check: its sentence, the same for every failure of that check, and what was seen.
class _Fault {
  final String check;
  final String detail;

  const _Fault(this.check, this.detail);
}

/// Swift's min for two times: the second when it is smaller, else the first.
Time _min(Time a, Time b) => b < a ? b : a;

/// The valid state of M1 and of seam J: every clip inside its source and a whole number of frames, the
/// playhead a whole frame from zero to the project length, the selection a clip of the project or none, every
/// text inside its limits, the selected text a text of the project or none, and a blank text only while it
/// is selected.
_Fault? _stateFault(EditorState state) {
  final project = state.project;
  final frame = Time.frame.ticks;
  for (final clip in project.clips) {
    final info = project.media[clip.media];
    if (info == null) {
      return _Fault('every clip lies inside its source', 'clip ${clip.id.raw} has no media facts');
    }
    if (clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration) {
      return _Fault(
        'every clip lies inside its source',
        'clip ${clip.id.raw} starts at ${clip.sourceStart.ticks} and is ${clip.duration.ticks} ticks long '
            'in a source of ${info.duration.ticks}',
      );
    }
    if (clip.duration.ticks.remainder(frame) != 0 || clip.duration < TimelineGeometry.minimumClip) {
      return _Fault(
        'every clip is a whole number of frames of at least minimumClip',
        'clip ${clip.id.raw} is ${clip.duration.ticks} ticks long',
      );
    }
  }
  if (state.playhead.ticks.remainder(frame) != 0 ||
      state.playhead < Time.zero ||
      state.playhead > project.duration) {
    return _Fault(
      'the playhead is a whole frame from zero to the project length',
      'it is at ${state.playhead.ticks} ticks in a project of ${project.duration.ticks}',
    );
  }
  final selection = state.selection;
  if (selection != null && !project.clips.any((clip) => clip.id == selection)) {
    return _Fault('the selection is a clip of the project', 'it is clip ${selection.raw}');
  }
  final width = project.canvas.width.toDouble();
  final height = project.canvas.height.toDouble();
  final ids = <TextID>{};
  for (final text in project.texts) {
    if (!ids.add(text.id)) {
      return _Fault('every text id is used once', '${text.id.raw} is used twice');
    }
    final span = text.span;
    if (span is TextSpanRange) {
      final range = span.range;
      if (range.start < Time.zero ||
          range.start.ticks.remainder(frame) != 0 ||
          range.duration.ticks.remainder(frame) != 0 ||
          range.duration < TextGeometry.minimumText) {
        return _Fault(
          'every range of a text is whole frames from zero and at least minimumText long',
          'text ${text.id.raw} starts at ${range.start.ticks} and is ${range.duration.ticks} ticks long',
        );
      }
    }
    if (!(text.style.size >= TextGeometry.minimumSize && text.style.size <= TextGeometry.maximumSize)) {
      return _Fault('every size of a text lies inside its limits', 'text ${text.id.raw} is ${text.style.size}');
    }
    if (!(text.x >= 0 && text.x <= width && text.y >= 0 && text.y <= height)) {
      return _Fault('every centre of a text lies inside the canvas', 'text ${text.id.raw} is at ${text.x}, ${text.y}');
    }
    if (!(text.rotation > -180 && text.rotation <= 180)) {
      return _Fault(
        'every rotation of a text is above minus 180 and at most 180',
        'text ${text.id.raw} is turned ${text.rotation}',
      );
    }
    if (text.isBlank && state.selectedText != text.id) {
      return _Fault('a blank text exists only while it is selected', 'text ${text.id.raw} is blank');
    }
  }
  final selected = state.selectedText;
  if (selected != null && project.text(selected) == null) {
    return _Fault('the selected text is a text of the project', 'it is text ${selected.raw}');
  }
  return null;
}

/// The valid state as seam P adds to it.
_Fault? _soundFault(EditorState state) {
  final project = state.project;
  final frame = Time.frame.ticks;
  if (!(project.clipVolume >= 0 && project.clipVolume <= 1)) {
    return _Fault('the volume of the clips lies from 0 to 1', 'it is ${project.clipVolume}');
  }
  final music = project.music;
  if (music != null) {
    if (!(music.volume >= 0 && music.volume <= 1)) {
      return _Fault('the volume of the music lies from 0 to 1', 'it is ${music.volume}');
    }
    if (music.start < Time.zero || music.start > music.largestStart || music.start.ticks.remainder(frame) != 0) {
      return _Fault(
        'the start of the music is a whole frame from zero to its largest start',
        'it is ${music.start.ticks} ticks and the largest start is ${music.largestStart.ticks}',
      );
    }
    for (final fade in [music.fadeIn, music.fadeOut]) {
      if (fade < Time.zero || fade > SoundGeometry.maximumFade || fade.ticks.remainder(frame) != 0) {
        return _Fault(
          'both fades are whole frames from zero to maximumFade',
          'the fade in is ${music.fadeIn.ticks} ticks and the fade out ${music.fadeOut.ticks}',
        );
      }
    }
    if (music.file.duration <= Time.zero) {
      return _Fault('the file of the music has a length above zero', 'it is ${music.file.duration.ticks} ticks');
    }
  }
  final set = [state.selection != null, state.selectedText != null, state.showsSound].where((value) => value).length;
  if (set > 1) {
    return _Fault(
      'at most one of selection, selectedText and showsSound is set',
      'selection ${state.selection?.raw}, selectedText ${state.selectedText?.raw}, showsSound ${state.showsSound}',
    );
  }
  if (state.showsSound && project.clips.isEmpty) {
    return const _Fault('showsSound is false on an empty project', 'it is true');
  }
  return null;
}

/// heardMusic, soundInfo and canSetMusicStart against the project.
_Fault? _readFault(EditorState state) {
  final project = state.project;
  final music = project.music;
  if (music != null && project.clips.isNotEmpty) {
    final expected = _min(music.file.duration - music.start, project.duration);
    if (project.heardMusic != expected || expected <= Time.zero) {
      return _Fault(
        'heardMusic is the smaller of the file less the start and the project, above zero',
        'it is ${project.heardMusic?.ticks} and the smaller is ${expected.ticks}',
      );
    }
  } else if (project.heardMusic != null) {
    return _Fault('heardMusic is nil when there is no music or no clip', 'it is ${project.heardMusic?.ticks}');
  }
  final fields = state.soundInfo.split(' ');
  if (fields.length != (music == null ? 3 : 6)) {
    return _Fault('soundInfo has three fields with no music and six with music', 'it is ${state.soundInfo}');
  }
  if ((fields[2] == 'hidden') != (music != null && project.clips.isEmpty)) {
    return _Fault(
      'the third field of soundInfo is hidden exactly when there is music and no clip',
      'it is ${state.soundInfo}',
    );
  }
  var fits = false;
  if (music != null) {
    fits = music.largestStart >= SoundGeometry.startStep;
  }
  if (state.canSetMusicStart != fits) {
    return _Fault(
      'canSetMusicStart is true exactly when the largest start of the music is at least startStep',
      'it is ${state.canSetMusicStart}',
    );
  }
  return null;
}

/// The kinds of a sound action that change the state and pause.
const List<_SoundKind> _pausing = [
  _SoundKind.setMusicLong,
  _SoundKind.setMusicShort,
  _SoundKind.setMusic500,
  _SoundKind.setMusic900,
  _SoundKind.removeMusic,
  _SoundKind.start,
  _SoundKind.startBelow,
  _SoundKind.startAbove,
  _SoundKind.startOffFrame,
];

/// What the action did that its kind must not do, or null.
_Fault? _editFault(EditorState before, EditorAction action, EditorState after, _SoundKind? kind) {
  final project = before.project;
  if (kind != null) {
    if (kind.leavesTheStateEqual && after != before) {
      return _Fault('a sound action with nothing to do returns the state equal', 'it was ${kind.rawValue}');
    }
    if (kind == _SoundKind.open && !(after.showsSound && after.selection == null && after.selectedText == null)) {
      return _Fault(
        'open on a project with a clip shows the panel and clears both selections',
        'showsSound ${after.showsSound}, selection ${after.selection?.raw}, selectedText ${after.selectedText?.raw}',
      );
    }
    if (action != EditorAction.sound(SoundAction.open) &&
        after != before &&
        after.isPlaying != (before.isPlaying && !_pausing.contains(kind))) {
      return _Fault('a sound action but open that changes the state pauses', 'it was ${kind.rawValue}');
    }
    return null;
  }
  if (after.project.clipVolume != project.clipVolume ||
      after.project.clipsMuted != project.clipsMuted ||
      after.project.music != project.music) {
    return _Fault(
      'no clip action and no text action changes sound',
      'the volume of the clips went from ${project.clipVolume} to ${after.project.clipVolume}, the mute from '
          '${project.clipsMuted} to ${after.project.clipsMuted}, the music changed: '
          '${after.project.music != project.music}',
    );
  }
  var closes = false;
  switch (action) {
    case EditorActionSelect(:final clip):
      closes = project.clips.any((candidate) => candidate.id == clip);
    case EditorActionText(textAction: TextActionSelect(:final id)):
      closes = project.text(id) != null;
    case EditorActionText(textAction: TextActionAdd()):
      closes = project.clips.isNotEmpty;
    case EditorActionClearSelection():
      closes = true;
    default:
      break;
  }
  if (closes && after.showsSound) {
    return const _Fault(
      'a select of a clip or a text, an add of a text and clearSelection close the panel',
      'it stayed open',
    );
  }
  return null;
}

/// Plays 1000 runs of 50 actions from the seed, with the start numbers 1 to 1000, and checks the state after
/// every action. The start state has the selected text and the open panel a start of the app on the seed has.
/// A run stops at its first failure and the next run is played. Each check fails once, with the first run
/// that broke it: its sentence goes into the failures.
void _playRuns(
  Seed seed,
  Map<_SoundKind, int> counts,
  Map<_ActionCase, int> cases,
  Set<String> reported,
  List<String> failures,
) {
  final start = EditorState(
    seed.project,
  ).copyWith(selectedText: () => seed.selectedText, showsSound: seed.showsSound);
  final startFault = _stateFault(start) ?? _soundFault(start);
  if (startFault != null) {
    failures.add('the start state of ${seed.rawValue} is not valid: ${startFault.check}: ${startFault.detail}');
    return;
  }
  for (var startNumber = 1; startNumber <= 1000; startNumber++) {
    final draw = _Draw(startNumber);
    var state = start;
    for (var sent = 1; sent <= 50; sent++) {
      final action = _drawAction(draw, state);
      _SoundKind? kind;
      if (action is EditorActionSound) {
        final drawn = _soundKind(action.soundAction, state);
        counts[drawn] = (counts[drawn] ?? 0) + 1;
        kind = drawn;
      } else {
        final drawn = _actionCase(action);
        if (drawn != null) {
          cases[drawn] = (cases[drawn] ?? 0) + 1;
        }
      }
      final next = reduce(state, action);
      final fault =
          _stateFault(next) ?? _soundFault(next) ?? _readFault(next) ?? _editFault(state, action, next, kind);
      if (fault != null) {
        if (reported.add(fault.check)) {
          failures.add(
            'seed ${seed.rawValue}, start number $startNumber, action $sent of 50: ${fault.check}: ${fault.detail}',
          );
        }
        break;
      }
      state = next;
    }
  }
}

void main() {
  test('testThreeThousandRunsOfFiftyClipTextAndSoundActionsKeepTheStateValidAndTheMusicInsideTheProject', () {
    final counts = <_SoundKind, int>{};
    final cases = <_ActionCase, int>{};
    final reported = <String>{};
    final failures = <String>[];
    for (final seed in [Seed.musicWide, Seed.textWide, Seed.threeClips]) {
      _playRuns(seed, counts, cases, reported, failures);
    }
    expect(failures, isEmpty);
    for (final actionCase in _ActionCase.values) {
      expect(cases[actionCase] ?? 0, greaterThan(0), reason: 'the runs never sent: ${actionCase.rawValue}');
    }
    for (final kind in _SoundKind.values) {
      expect(counts[kind] ?? 0, greaterThan(0), reason: 'the runs never drew: ${kind.rawValue}');
    }
  });
}
