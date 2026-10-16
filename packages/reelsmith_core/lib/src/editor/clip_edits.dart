// Moving a clip and cutting the selected clip at the playhead, and the values the clip panel reads.

import 'dart:math';

import '../model/project.dart';
import '../model/time.dart';
import 'editor_state.dart';
import 'timeline_geometry.dart';

extension EditorStateClipEdits on EditorState {
  /// The playhead is inside the selected clip with at least minimumClip on both sides of it.
  bool get canCutBefore => _cutPlace(this) != null;

  /// The playhead is inside the selected clip with at least minimumClip on both sides of it.
  bool get canCutAfter => _cutPlace(this) != null;

  /// The selection names a clip of the project.
  bool get showsClipPanel {
    final selection = this.selection;
    if (selection == null) {
      return false;
    }
    return project.positionOfClip(selection) != null;
  }

  /// showsClipPanel, and the media of the selected clip has sound.
  bool get showsClipVolume {
    final selection = this.selection;
    if (!showsClipPanel || selection == null) {
      return false;
    }
    for (final clip in project.clips) {
      if (clip.id == selection) {
        return project.media[clip.media]?.hasSound == true;
      }
    }
    return false;
  }
}

extension ProjectClipEdits on Project {
  /// The Swift dropPosition(of:at:). The position from 1 the clip takes when let go at the time: 1 plus the count
  /// of the other clips, in their order with the clip taken out, whose middle is before the time. Null for an
  /// unknown id.
  int? dropPosition({required ClipID of, required Time at}) {
    final clip = of;
    final time = at;
    if (positionOfClip(clip) == null) {
      return null;
    }
    var start = Time.zero;
    var before = 0;
    for (final other in clips) {
      if (other.id == clip) {
        continue;
      }
      if (start + Time(ticks: other.duration.ticks ~/ 2) < time) {
        before += 1;
      }
      start = start + other.duration;
    }
    return before + 1;
  }
}

EditorState moveClip(EditorState state, ClipID clip, int position) {
  final index = state.project.clips.indexWhere((candidate) => candidate.id == clip);
  if (index < 0) {
    return state;
  }
  final target = min(max(position, 1), state.project.clips.length) - 1;
  if (target == index) {
    return state;
  }
  final clips = List.of(state.project.clips);
  final moved = clips.removeAt(index);
  clips.insert(target, moved);
  return state.copyWith(
    project: state.project.copyWith(clips: clips),
    selection: () => clip,
    selectedText: () => null,
    isPlaying: false,
  );
}

EditorState cutBefore(EditorState state) {
  final place = _cutPlace(state);
  if (place == null) {
    return state;
  }
  final clips = List.of(state.project.clips);
  final old = clips[place.index];
  clips[place.index] = old.copyWith(sourceStart: old.sourceStart + place.left, duration: old.duration - place.left);
  return state.copyWith(project: state.project.copyWith(clips: clips), playhead: place.start, isPlaying: false);
}

EditorState cutAfter(EditorState state) {
  final place = _cutPlace(state);
  if (place == null) {
    return state;
  }
  final clips = List.of(state.project.clips);
  clips[place.index] = clips[place.index].copyWith(duration: place.left);
  return state.copyWith(project: state.project.copyWith(clips: clips), isPlaying: false);
}

/// The index and the start of the selected clip and the part of it before the playhead, when at least
/// minimumClip lies on both sides of the playhead inside that clip. Null otherwise.
({int index, Time start, Time left})? _cutPlace(EditorState state) {
  final selection = state.selection;
  final index = selection == null ? -1 : state.project.clips.indexWhere((clip) => clip.id == selection);
  final start = selection == null ? null : state.project.start(selection);
  if (index < 0 || start == null) {
    return null;
  }
  final left = state.playhead - start;
  final right = state.project.clips[index].duration - left;
  if (!(left >= TimelineGeometry.minimumClip && right >= TimelineGeometry.minimumClip)) {
    return null;
  }
  return (index: index, start: start, left: left);
}
