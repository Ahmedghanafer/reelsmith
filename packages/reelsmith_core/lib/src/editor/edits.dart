// The edit actions and the values that enable their buttons.

import '../model/media.dart';
import '../model/project.dart';
import '../model/time.dart';
import 'editor_state.dart';
import 'timeline_geometry.dart';

extension EditorStateEdits on EditorState {
  bool get canSplit {
    final clip = project.clip(playhead);
    final start = clip == null ? null : project.start(clip.id);
    if (clip == null || start == null) {
      return false;
    }
    final left = playhead - start;
    return left >= TimelineGeometry.minimumClip && clip.duration - left >= TimelineGeometry.minimumClip;
  }

  bool get canDelete {
    final selectedText = this.selectedText;
    if (selectedText != null) {
      return project.text(selectedText) != null;
    }
    final selection = this.selection;
    if (selection == null) {
      return false;
    }
    return project.positionOfClip(selection) != null;
  }
}

EditorState addClips(EditorState state, List<MediaInfo> media) {
  final clips = List.of(state.project.clips);
  final stored = Map.of(state.project.media);
  var nextClipID = state.project.nextClipID;
  for (final given in media) {
    // A media that a clip uses keeps the facts it has, so that clip stays inside its source.
    var info = given;
    final kept = stored[given.id];
    if (kept != null && clips.any((clip) => clip.media == given.id)) {
      info = kept;
    }
    // A photo comes in for photoLength, and its trims reach up to its media duration.
    final duration = info.kind == MediaKind.photo ? MediaInfo.photoLength : info.duration.roundedDownToFrame;
    if (duration < TimelineGeometry.minimumClip) {
      continue;
    }
    stored[info.id] = info;
    clips.add(Clip(id: ClipID(nextClipID), media: info.id, sourceStart: Time.zero, duration: duration));
    nextClipID += 1;
  }
  return state.copyWith(
    project: state.project.copyWith(clips: clips, media: stored, nextClipID: nextClipID),
    isPlaying: false,
  );
}

EditorState split(EditorState state) {
  final clip = state.project.clip(state.playhead);
  final start = clip == null ? null : state.project.start(clip.id);
  final index = clip == null ? -1 : state.project.clips.indexWhere((candidate) => candidate.id == clip.id);
  if (!state.canSplit || clip == null || start == null || index < 0) {
    return state;
  }
  final left = state.playhead - start;
  final clips = List.of(state.project.clips);
  clips[index] = clips[index].copyWith(duration: left);
  clips.insert(
    index + 1,
    Clip(
      id: ClipID(state.project.nextClipID),
      media: clip.media,
      sourceStart: clip.sourceStart + left,
      duration: clip.duration - left,
      volume: clip.volume,
      framing: clip.framing,
    ),
  );
  return state.copyWith(
    project: state.project.copyWith(clips: clips, nextClipID: state.project.nextClipID + 1),
    isPlaying: false,
  );
}

EditorState trimStart(EditorState state, ClipID clip, Time amount) {
  final index = state.project.clips.indexWhere((candidate) => candidate.id == clip);
  if (index < 0 || state.project.media[state.project.clips[index].media] == null) {
    return state;
  }
  final old = state.project.clips[index];
  final change = _wholeFrames(amount, Time.zero - old.sourceStart, old.duration - TimelineGeometry.minimumClip);
  final clips = List.of(state.project.clips);
  clips[index] = old.copyWith(sourceStart: old.sourceStart + change, duration: old.duration - change);
  return _afterTrim(state.copyWith(project: state.project.copyWith(clips: clips)));
}

EditorState trimEnd(EditorState state, ClipID clip, Time amount) {
  final index = state.project.clips.indexWhere((candidate) => candidate.id == clip);
  final info = index < 0 ? null : state.project.media[state.project.clips[index].media];
  if (index < 0 || info == null) {
    return state;
  }
  final old = state.project.clips[index];
  final change = _wholeFrames(
    amount,
    old.sourceStart + old.duration - info.duration,
    old.duration - TimelineGeometry.minimumClip,
  );
  final clips = List.of(state.project.clips);
  clips[index] = old.copyWith(duration: old.duration - change);
  return _afterTrim(state.copyWith(project: state.project.copyWith(clips: clips)));
}

EditorState deleteSelected(EditorState state) {
  // A selected text is what is deleted, and then no clip is touched.
  final selectedText = state.selectedText;
  if (selectedText != null) {
    final index = state.project.texts.indexWhere((text) => text.id == selectedText);
    if (index < 0) {
      return state;
    }
    final texts = List.of(state.project.texts)..removeAt(index);
    return state.copyWith(
      project: state.project.copyWith(texts: texts),
      selectedText: () => null,
      isPlaying: false,
    );
  }
  final selection = state.selection;
  final index = selection == null ? -1 : state.project.clips.indexWhere((clip) => clip.id == selection);
  if (index < 0) {
    return state;
  }
  final clips = List.of(state.project.clips)..removeAt(index);
  final project = state.project.copyWith(clips: clips);
  return state.copyWith(
    project: project,
    selection: () => null,
    playhead: _min(state.playhead, project.duration),
    isPlaying: false,
  );
}

/// The amount held between the two limits, then rounded toward zero to whole frames.
Time _wholeFrames(Time amount, Time low, Time high) {
  final held = _min(_max(amount, low), high);
  return Time(ticks: held.ticks ~/ Time.frame.ticks * Time.frame.ticks);
}

EditorState _afterTrim(EditorState state) =>
    state.copyWith(playhead: _min(state.playhead, state.project.duration), isPlaying: false);

/// Swift's min: the second when it is less than the first, else the first.
Time _min(Time a, Time b) => b < a ? b : a;

/// Swift's max: the second when it is at least the first, else the first.
Time _max(Time a, Time b) => b >= a ? b : a;
