import '../model/time.dart';
import 'clip_edits.dart';
import 'editor_action.dart';
import 'editor_state.dart';
import 'edits.dart';
import 'frame_edits.dart';
import 'sound_edits.dart';
import 'text_edits.dart';

/// An action that cannot be done returns the state unchanged. Pure and synchronous, so a gesture can call it
/// inside a frame.
EditorState reduce(EditorState state, EditorAction action) => settleSound(settleTexts(state, _step(state, action)));

EditorState _step(EditorState state, EditorAction action) {
  switch (action) {
    case EditorActionAddClips(:final media):
      return addClips(state, media);
    case EditorActionSplit():
      return split(state);
    case EditorActionTrimStart(:final clip, :final amount):
      return trimStart(state, clip, amount);
    case EditorActionTrimEnd(:final clip, :final amount):
      return trimEnd(state, clip, amount);
    case EditorActionDeleteSelected():
      return deleteSelected(state);
    case EditorActionMoveClip(:final clip, :final position):
      return moveClip(state, clip, position);
    case EditorActionCutBefore():
      return cutBefore(state);
    case EditorActionCutAfter():
      return cutAfter(state);
    case EditorActionSelect(:final clip):
      if (state.project.positionOfClip(clip) != null) {
        return state.copyWith(selection: () => clip, selectedText: () => null);
      }
      return state;
    case EditorActionClearSelection():
      return state.copyWith(selection: () => null, selectedText: () => null, showsSound: false);
    case EditorActionMovePlayhead(:final time):
      final atLeastZero = Time.zero >= time ? Time.zero : time;
      final duration = state.project.duration;
      return state.copyWith(playhead: (duration < atLeastZero ? duration : atLeastZero).roundedDownToFrame);
    case EditorActionPlay():
      if (!state.canPlay) {
        return state;
      }
      return state.copyWith(
        playhead: state.playhead >= state.project.duration ? Time.zero : state.playhead,
        isPlaying: true,
      );
    case EditorActionPause():
      return state.copyWith(isPlaying: false);
    case EditorActionText(:final textAction):
      return reduceText(state, textAction);
    case EditorActionSound(:final soundAction):
      return reduceSound(state, soundAction);
    case EditorActionFrame(:final frameAction):
      return reduceFrame(state, frameAction);
  }
}
