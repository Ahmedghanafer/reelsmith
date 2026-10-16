import '../model/media.dart';
import '../model/project.dart';
import '../model/time.dart';
import 'frame_action.dart';
import 'sound_action.dart';
import 'text_action.dart';

/// The Swift enum EditorAction, one subclass per case, so reduce switches over every case.
sealed class EditorAction {
  const EditorAction();

  /// To the end, in order: a video whole and rounded down to a frame, a photo for photoLength.
  factory EditorAction.addClips(List<MediaInfo> media) = EditorActionAddClips;

  /// At the playhead.
  static const EditorAction split = EditorActionSplit();

  /// A positive amount makes the clip shorter. Rounded toward zero to whole frames. Sent once, on release.
  const factory EditorAction.trimStart(ClipID clip, Time amount) = EditorActionTrimStart;

  /// A positive amount makes the clip shorter. Rounded toward zero to whole frames. Sent once, on release.
  const factory EditorAction.trimEnd(ClipID clip, Time amount) = EditorActionTrimEnd;

  /// Deleting the last clip leaves an empty project.
  static const EditorAction deleteSelected = EditorActionDeleteSelected();

  /// To a position from 1, held between 1 and the count. Nothing for an unknown id or the position it has.
  /// Keeps the playhead, selects the clip, pauses.
  const factory EditorAction.moveClip(ClipID clip, int position) = EditorActionMoveClip;

  /// The selected clip, at the playhead, when canCutBefore.
  static const EditorAction cutBefore = EditorActionCutBefore();

  /// The selected clip, at the playhead, when canCutAfter.
  static const EditorAction cutAfter = EditorActionCutAfter();

  const factory EditorAction.select(ClipID clip) = EditorActionSelect;

  static const EditorAction clearSelection = EditorActionClearSelection();

  /// Clamped to the project, rounded down to a frame, leaves isPlaying alone.
  const factory EditorAction.movePlayhead(Time time) = EditorActionMovePlayhead;

  /// From zero when the playhead is at the end. Nothing on an empty project.
  static const EditorAction play = EditorActionPlay();

  static const EditorAction pause = EditorActionPause();

  const factory EditorAction.text(TextAction textAction) = EditorActionText;

  const factory EditorAction.sound(SoundAction soundAction) = EditorActionSound;

  /// Nothing for an unknown id or a value that is not finite.
  const factory EditorAction.frame(FrameAction frameAction) = EditorActionFrame;
}

final class EditorActionAddClips extends EditorAction {
  final List<MediaInfo> media;

  /// The media are copied into an unmodifiable list, as with Swift's value types.
  EditorActionAddClips(List<MediaInfo> media) : media = List<MediaInfo>.unmodifiable(media);

  EditorActionAddClips copyWith({List<MediaInfo>? media}) => EditorActionAddClips(media ?? this.media);

  @override
  bool operator ==(Object other) {
    if (other is! EditorActionAddClips || other.media.length != media.length) {
      return false;
    }
    for (var index = 0; index < media.length; index++) {
      if (other.media[index] != media[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(EditorActionAddClips, Object.hashAll(media));
}

final class EditorActionSplit extends EditorAction {
  const EditorActionSplit();

  @override
  bool operator ==(Object other) => other is EditorActionSplit;

  @override
  int get hashCode => (EditorActionSplit).hashCode;
}

final class EditorActionTrimStart extends EditorAction {
  final ClipID clip;
  final Time amount;

  const EditorActionTrimStart(this.clip, this.amount);

  EditorActionTrimStart copyWith({ClipID? clip, Time? amount}) =>
      EditorActionTrimStart(clip ?? this.clip, amount ?? this.amount);

  @override
  bool operator ==(Object other) => other is EditorActionTrimStart && other.clip == clip && other.amount == amount;

  @override
  int get hashCode => Object.hash(EditorActionTrimStart, clip, amount);
}

final class EditorActionTrimEnd extends EditorAction {
  final ClipID clip;
  final Time amount;

  const EditorActionTrimEnd(this.clip, this.amount);

  EditorActionTrimEnd copyWith({ClipID? clip, Time? amount}) =>
      EditorActionTrimEnd(clip ?? this.clip, amount ?? this.amount);

  @override
  bool operator ==(Object other) => other is EditorActionTrimEnd && other.clip == clip && other.amount == amount;

  @override
  int get hashCode => Object.hash(EditorActionTrimEnd, clip, amount);
}

final class EditorActionDeleteSelected extends EditorAction {
  const EditorActionDeleteSelected();

  @override
  bool operator ==(Object other) => other is EditorActionDeleteSelected;

  @override
  int get hashCode => (EditorActionDeleteSelected).hashCode;
}

final class EditorActionMoveClip extends EditorAction {
  final ClipID clip;
  final int position;

  const EditorActionMoveClip(this.clip, this.position);

  EditorActionMoveClip copyWith({ClipID? clip, int? position}) =>
      EditorActionMoveClip(clip ?? this.clip, position ?? this.position);

  @override
  bool operator ==(Object other) => other is EditorActionMoveClip && other.clip == clip && other.position == position;

  @override
  int get hashCode => Object.hash(EditorActionMoveClip, clip, position);
}

final class EditorActionCutBefore extends EditorAction {
  const EditorActionCutBefore();

  @override
  bool operator ==(Object other) => other is EditorActionCutBefore;

  @override
  int get hashCode => (EditorActionCutBefore).hashCode;
}

final class EditorActionCutAfter extends EditorAction {
  const EditorActionCutAfter();

  @override
  bool operator ==(Object other) => other is EditorActionCutAfter;

  @override
  int get hashCode => (EditorActionCutAfter).hashCode;
}

final class EditorActionSelect extends EditorAction {
  final ClipID clip;

  const EditorActionSelect(this.clip);

  EditorActionSelect copyWith({ClipID? clip}) => EditorActionSelect(clip ?? this.clip);

  @override
  bool operator ==(Object other) => other is EditorActionSelect && other.clip == clip;

  @override
  int get hashCode => Object.hash(EditorActionSelect, clip);
}

final class EditorActionClearSelection extends EditorAction {
  const EditorActionClearSelection();

  @override
  bool operator ==(Object other) => other is EditorActionClearSelection;

  @override
  int get hashCode => (EditorActionClearSelection).hashCode;
}

final class EditorActionMovePlayhead extends EditorAction {
  final Time time;

  const EditorActionMovePlayhead(this.time);

  EditorActionMovePlayhead copyWith({Time? time}) => EditorActionMovePlayhead(time ?? this.time);

  @override
  bool operator ==(Object other) => other is EditorActionMovePlayhead && other.time == time;

  @override
  int get hashCode => Object.hash(EditorActionMovePlayhead, time);
}

final class EditorActionPlay extends EditorAction {
  const EditorActionPlay();

  @override
  bool operator ==(Object other) => other is EditorActionPlay;

  @override
  int get hashCode => (EditorActionPlay).hashCode;
}

final class EditorActionPause extends EditorAction {
  const EditorActionPause();

  @override
  bool operator ==(Object other) => other is EditorActionPause;

  @override
  int get hashCode => (EditorActionPause).hashCode;
}

final class EditorActionText extends EditorAction {
  final TextAction textAction;

  const EditorActionText(this.textAction);

  EditorActionText copyWith({TextAction? textAction}) => EditorActionText(textAction ?? this.textAction);

  @override
  bool operator ==(Object other) => other is EditorActionText && other.textAction == textAction;

  @override
  int get hashCode => Object.hash(EditorActionText, textAction);
}

final class EditorActionSound extends EditorAction {
  final SoundAction soundAction;

  const EditorActionSound(this.soundAction);

  EditorActionSound copyWith({SoundAction? soundAction}) => EditorActionSound(soundAction ?? this.soundAction);

  @override
  bool operator ==(Object other) => other is EditorActionSound && other.soundAction == soundAction;

  @override
  int get hashCode => Object.hash(EditorActionSound, soundAction);
}

final class EditorActionFrame extends EditorAction {
  final FrameAction frameAction;

  const EditorActionFrame(this.frameAction);

  EditorActionFrame copyWith({FrameAction? frameAction}) => EditorActionFrame(frameAction ?? this.frameAction);

  @override
  bool operator ==(Object other) => other is EditorActionFrame && other.frameAction == frameAction;

  @override
  int get hashCode => Object.hash(EditorActionFrame, frameAction);
}
