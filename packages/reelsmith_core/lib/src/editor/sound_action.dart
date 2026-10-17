import '../model/project.dart';
import '../model/sound.dart';
import '../model/time.dart';

/// The Swift enum SoundAction, one subclass per case.
sealed class SoundAction {
  const SoundAction();

  /// Shows the sound panel and clears both selections. Leaves isPlaying alone. Nothing on an empty project.
  static const SoundAction open = SoundActionOpen();

  /// Held between 0 and 1.
  const factory SoundAction.setClipVolume(double volume) = SoundActionSetClipVolume;

  const factory SoundAction.muteClips(bool muted) = SoundActionMuteClips;

  /// Replaces any music by Music.file. Nothing for a file with no length.
  const factory SoundAction.setMusic(MusicFile file) = SoundActionSetMusic;

  static const SoundAction removeMusic = SoundActionRemoveMusic();

  /// Held between 0 and 1.
  const factory SoundAction.setMusicVolume(double volume) = SoundActionSetMusicVolume;

  /// Held between zero and the largest start, rounded toward zero to a whole frame.
  const factory SoundAction.setMusicStart(Time start) = SoundActionSetMusicStart;

  /// Held between zero and maximumFade, rounded toward zero to a whole frame.
  const factory SoundAction.setFadeIn(Time fade) = SoundActionSetFadeIn;

  /// Held between zero and maximumFade, rounded toward zero to a whole frame.
  const factory SoundAction.setFadeOut(Time fade) = SoundActionSetFadeOut;

  /// Held between 0 and 2. Nothing for an unknown clip or a value that is not finite.
  const factory SoundAction.setVolumeOfClip(ClipID id, double volume) = SoundActionSetVolumeOfClip;
}

final class SoundActionOpen extends SoundAction {
  const SoundActionOpen();

  @override
  bool operator ==(Object other) => other is SoundActionOpen;

  @override
  int get hashCode => (SoundActionOpen).hashCode;
}

final class SoundActionSetClipVolume extends SoundAction {
  final double volume;

  const SoundActionSetClipVolume(this.volume);

  SoundActionSetClipVolume copyWith({double? volume}) => SoundActionSetClipVolume(volume ?? this.volume);

  @override
  bool operator ==(Object other) => other is SoundActionSetClipVolume && other.volume == volume;

  @override
  int get hashCode => Object.hash(SoundActionSetClipVolume, volume);
}

final class SoundActionMuteClips extends SoundAction {
  final bool muted;

  const SoundActionMuteClips(this.muted);

  SoundActionMuteClips copyWith({bool? muted}) => SoundActionMuteClips(muted ?? this.muted);

  @override
  bool operator ==(Object other) => other is SoundActionMuteClips && other.muted == muted;

  @override
  int get hashCode => Object.hash(SoundActionMuteClips, muted);
}

final class SoundActionSetMusic extends SoundAction {
  final MusicFile file;

  const SoundActionSetMusic(this.file);

  SoundActionSetMusic copyWith({MusicFile? file}) => SoundActionSetMusic(file ?? this.file);

  @override
  bool operator ==(Object other) => other is SoundActionSetMusic && other.file == file;

  @override
  int get hashCode => Object.hash(SoundActionSetMusic, file);
}

final class SoundActionRemoveMusic extends SoundAction {
  const SoundActionRemoveMusic();

  @override
  bool operator ==(Object other) => other is SoundActionRemoveMusic;

  @override
  int get hashCode => (SoundActionRemoveMusic).hashCode;
}

final class SoundActionSetMusicVolume extends SoundAction {
  final double volume;

  const SoundActionSetMusicVolume(this.volume);

  SoundActionSetMusicVolume copyWith({double? volume}) => SoundActionSetMusicVolume(volume ?? this.volume);

  @override
  bool operator ==(Object other) => other is SoundActionSetMusicVolume && other.volume == volume;

  @override
  int get hashCode => Object.hash(SoundActionSetMusicVolume, volume);
}

final class SoundActionSetMusicStart extends SoundAction {
  final Time start;

  const SoundActionSetMusicStart(this.start);

  SoundActionSetMusicStart copyWith({Time? start}) => SoundActionSetMusicStart(start ?? this.start);

  @override
  bool operator ==(Object other) => other is SoundActionSetMusicStart && other.start == start;

  @override
  int get hashCode => Object.hash(SoundActionSetMusicStart, start);
}

final class SoundActionSetFadeIn extends SoundAction {
  final Time fade;

  const SoundActionSetFadeIn(this.fade);

  SoundActionSetFadeIn copyWith({Time? fade}) => SoundActionSetFadeIn(fade ?? this.fade);

  @override
  bool operator ==(Object other) => other is SoundActionSetFadeIn && other.fade == fade;

  @override
  int get hashCode => Object.hash(SoundActionSetFadeIn, fade);
}

final class SoundActionSetFadeOut extends SoundAction {
  final Time fade;

  const SoundActionSetFadeOut(this.fade);

  SoundActionSetFadeOut copyWith({Time? fade}) => SoundActionSetFadeOut(fade ?? this.fade);

  @override
  bool operator ==(Object other) => other is SoundActionSetFadeOut && other.fade == fade;

  @override
  int get hashCode => Object.hash(SoundActionSetFadeOut, fade);
}

final class SoundActionSetVolumeOfClip extends SoundAction {
  final ClipID id;
  final double volume;

  const SoundActionSetVolumeOfClip(this.id, this.volume);

  SoundActionSetVolumeOfClip copyWith({ClipID? id, double? volume}) =>
      SoundActionSetVolumeOfClip(id ?? this.id, volume ?? this.volume);

  @override
  bool operator ==(Object other) => other is SoundActionSetVolumeOfClip && other.id == id && other.volume == volume;

  @override
  int get hashCode => Object.hash(SoundActionSetVolumeOfClip, id, volume);
}
