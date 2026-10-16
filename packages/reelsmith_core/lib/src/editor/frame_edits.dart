// The frame actions and the values the framing row and the gestures on the picture read.

import '../model/framing.dart';
import '../model/project.dart';
import 'editor_state.dart';
import 'frame_action.dart';

extension EditorStateFrameEdits on EditorState {
  /// The selected clip while no text is selected and the playhead is inside that clip. Null otherwise (rule 90).
  ClipID? get framedByHand {
    final selection = this.selection;
    if (selectedText != null || selection == null || project.clip(playhead)?.id != selection) {
      return null;
    }
    return selection;
  }

  /// "none" with no clip selected. Else "<fit|fill> <black|blur> <zoom times 100> <x times 1000>,<y times 1000>"
  /// of the selected clip, whole numbers with the digits 0 to 9, the same in every language: "fit black 100 0,0".
  String get frameInfo {
    final selection = this.selection;
    Clip? clip;
    for (final candidate in project.clips) {
      if (candidate.id == selection) {
        clip = candidate;
        break;
      }
    }
    if (selection == null || clip == null) {
      return 'none';
    }
    final framing = clip.framing;
    final backdrop = framing.backdrop == Backdrop.black ? 'black' : 'blur';
    return '${framing.fit.rawValue} $backdrop ${_whole(framing.zoom * 100)} '
        '${_whole(framing.x * 1000)},${_whole(framing.y * 1000)}';
  }
}

/// What reduce calls for the case frame. Nothing for an unknown id or a value that is not finite. Every framing
/// the action changes is stored held (rule 84). An action that changes the state pauses, one that would change
/// nothing returns the state unchanged.
EditorState reduceFrame(EditorState state, FrameAction action) {
  final clips = List.of(state.project.clips);
  int place(ClipID id) => clips.indexWhere((clip) => clip.id == id);
  switch (action) {
    case FrameActionSetFit(:final id, :final fit):
      final index = place(id);
      if (index < 0) {
        return state;
      }
      clips[index] = clips[index].copyWith(framing: clips[index].framing.copyWith(fit: fit));
    case FrameActionSetBackdrop(:final id, :final backdrop):
      final index = place(id);
      if (index < 0) {
        return state;
      }
      clips[index] = clips[index].copyWith(framing: clips[index].framing.copyWith(backdrop: backdrop));
    case FrameActionSetZoom(:final id, :final zoom):
      final index = place(id);
      if (!zoom.isFinite || index < 0) {
        return state;
      }
      clips[index] = clips[index].copyWith(framing: clips[index].framing.copyWith(zoom: zoom));
    case FrameActionSetOffset(:final id, :final x, :final y):
      final index = place(id);
      if (!x.isFinite || !y.isFinite || index < 0) {
        return state;
      }
      clips[index] = clips[index].copyWith(framing: clips[index].framing.copyWith(x: x, y: y));
    case FrameActionApplyToAll(:final id):
      final index = place(id);
      if (index < 0) {
        return state;
      }
      final source = clips[index];
      for (var other = 0; other < clips.length; other++) {
        clips[other] = clips[other].copyWith(
          framing: clips[other].framing.copyWith(fit: source.framing.fit, backdrop: source.framing.backdrop),
        );
      }
  }
  for (var index = 0; index < clips.length; index++) {
    final clip = clips[index];
    if (clip == state.project.clips[index]) {
      continue;
    }
    final info = state.project.media[clip.media];
    if (info == null) {
      continue;
    }
    final turned = info.quarterTurns % 2 != 0;
    clips[index] = clip.copyWith(
      framing: clip.framing.held(
        uprightWidth: (turned ? info.height : info.width).toDouble(),
        uprightHeight: (turned ? info.width : info.height).toDouble(),
        canvas: state.project.canvas,
      ),
    );
  }
  final project = state.project.copyWith(clips: clips);
  if (project == state.project) {
    return state;
  }
  return state.copyWith(project: project, isPlaying: false);
}

/// A number rounded to a whole one, written with the digits 0 to 9.
String _whole(double value) => '${value.round()}';
