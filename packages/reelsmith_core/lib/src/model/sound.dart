import 'media.dart';
import 'time.dart';

class MusicFile {
  /// A test tone uses its name, a picked file a new UUID string.
  final MediaID id;

  /// The file's name inside the media folder, with its extension.
  final String fileName;

  /// Content: the name of the picked file without its extension.
  final String title;

  /// The length of its first sound track, rounded down to a tick.
  final Time duration;

  const MusicFile({required this.id, required this.fileName, required this.title, required this.duration});

  MusicFile copyWith({MediaID? id, String? fileName, String? title, Time? duration}) => MusicFile(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    title: title ?? this.title,
    duration: duration ?? this.duration,
  );

  @override
  bool operator ==(Object other) =>
      other is MusicFile &&
      other.id == id &&
      other.fileName == fileName &&
      other.title == title &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(id, fileName, title, duration);
}

class Music {
  final MusicFile file;

  /// The place in the file where the music begins. A whole frame.
  final Time start;

  /// 0 to 1.
  final double volume;

  /// Whole frames, 0 to SoundGeometry.maximumFade.
  final Time fadeIn;

  /// Whole frames, 0 to SoundGeometry.maximumFade.
  final Time fadeOut;

  const Music({
    required this.file,
    required this.start,
    required this.volume,
    required this.fadeIn,
    required this.fadeOut,
  });

  /// Start zero, volume 1, both fades zero.
  const Music.file(this.file) : start = Time.zero, volume = 1, fadeIn = Time.zero, fadeOut = Time.zero;

  /// The length of the file less SoundGeometry.minimumMusic, rounded down to a whole frame.
  /// Zero for a file not longer than minimumMusic.
  Time get largestStart {
    final start = (file.duration - SoundGeometry.minimumMusic).roundedDownToFrame;
    return start >= Time.zero ? start : Time.zero;
  }

  Music copyWith({MusicFile? file, Time? start, double? volume, Time? fadeIn, Time? fadeOut}) => Music(
    file: file ?? this.file,
    start: start ?? this.start,
    volume: volume ?? this.volume,
    fadeIn: fadeIn ?? this.fadeIn,
    fadeOut: fadeOut ?? this.fadeOut,
  );

  @override
  bool operator ==(Object other) =>
      other is Music &&
      other.file == file &&
      other.start == start &&
      other.volume == volume &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut;

  @override
  int get hashCode => Object.hash(file, start, volume, fadeIn, fadeOut);
}

abstract final class SoundGeometry {
  /// Five seconds.
  static const Time maximumFade = Time(ticks: 3000);

  /// A start leaves at least this much of the file.
  static const Time minimumMusic = Time(ticks: 600);

  /// The step of the slider that sets the start.
  static const Time startStep = Time(ticks: 600);
}
