// The sound actions and the rule that at most one of a clip, a text and the sound panel is open.

import 'dart:math';

import '../model/sound.dart';
import '../model/time.dart';
import 'editor_state.dart';
import 'sound_action.dart';

/// What reduce calls for the case sound. A value past a limit is held at the limit. An action that would change
/// nothing returns the state unchanged, the playing flag included, and so does a volume that is not a finite number,
/// a volume of a clip the project does not have and, for the four that name the music, an action with no music.
/// An action that changes only a level (the volume of the clips, the mute, the volume of a clip, the volume of the
/// music and its two fades) leaves isPlaying as it was. Every other one but open that changes the state pauses.
EditorState reduceSound(EditorState state, SoundAction action) {
  var project = state.project;
  final music = project.music;
  switch (action) {
    case SoundActionOpen():
      if (!state.canOpenSound) {
        return state;
      }
      return state.copyWith(showsSound: true, selection: () => null, selectedText: () => null);
    case SoundActionSetClipVolume(:final volume):
      if (!volume.isFinite) {
        return state;
      }
      project = project.copyWith(clipVolume: min(max(volume, 0.0), 1.0));
    case SoundActionMuteClips(:final muted):
      project = project.copyWith(clipsMuted: muted);
    case SoundActionSetMusic(:final file):
      if (!(file.duration > Time.zero)) {
        return state;
      }
      project = project.copyWith(music: () => Music.file(file));
    case SoundActionRemoveMusic():
      project = project.copyWith(music: () => null);
    case SoundActionSetMusicVolume(:final volume):
      if (!volume.isFinite || music == null) {
        return state;
      }
      project = project.copyWith(music: () => music.copyWith(volume: min(max(volume, 0.0), 1.0)));
    case SoundActionSetMusicStart(:final start):
      if (music == null) {
        return state;
      }
      project = project.copyWith(music: () => music.copyWith(start: _held(start, music.largestStart)));
    case SoundActionSetFadeIn(:final fade):
      if (music == null) {
        return state;
      }
      project = project.copyWith(music: () => music.copyWith(fadeIn: _held(fade, SoundGeometry.maximumFade)));
    case SoundActionSetFadeOut(:final fade):
      if (music == null) {
        return state;
      }
      project = project.copyWith(music: () => music.copyWith(fadeOut: _held(fade, SoundGeometry.maximumFade)));
    case SoundActionSetVolumeOfClip(:final id, :final volume):
      final index = project.clips.indexWhere((clip) => clip.id == id);
      if (!volume.isFinite || index < 0) {
        return state;
      }
      final clips = List.of(project.clips);
      clips[index] = clips[index].copyWith(volume: min(max(volume, 0.0), 2.0));
      project = project.copyWith(clips: clips);
  }
  if (project == state.project) {
    return state;
  }
  switch (action) {
    case SoundActionSetClipVolume() ||
        SoundActionMuteClips() ||
        SoundActionSetVolumeOfClip() ||
        SoundActionSetMusicVolume() ||
        SoundActionSetFadeIn() ||
        SoundActionSetFadeOut():
      return state.copyWith(project: project);
    case SoundActionOpen() || SoundActionSetMusic() || SoundActionRemoveMusic() || SoundActionSetMusicStart():
      return state.copyWith(project: project, isPlaying: false);
  }
}

/// Called by reduce on every path, last. Closes the sound panel when a clip or a text is selected
/// and on an empty project, and changes nothing else.
EditorState settleSound(EditorState state) {
  if (!(state.showsSound &&
      (state.selection != null || state.selectedText != null || state.project.clips.isEmpty))) {
    return state;
  }
  return state.copyWith(showsSound: false);
}

/// The time held between zero and the upper limit, a whole frame, then rounded toward zero to a whole frame.
Time _held(Time time, Time upper) {
  final low = time >= Time.zero ? time : Time.zero;
  return (upper < low ? upper : low).roundedDownToFrame;
}
