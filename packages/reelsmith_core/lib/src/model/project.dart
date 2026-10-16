import 'canvas.dart';
import 'framing.dart';
import 'media.dart';
import 'sound.dart';
import 'text.dart';
import 'time.dart';

class ClipID {
  final int raw;

  const ClipID(this.raw);

  ClipID copyWith({int? raw}) => ClipID(raw ?? this.raw);

  @override
  bool operator ==(Object other) => other is ClipID && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}

class Clip {
  final ClipID id;
  final MediaID media;
  final Time sourceStart;
  final Time duration;

  /// 0 to 2, a factor on the volume of the clips. 1 when a stored file lacks it.
  final double volume;

  /// How the picture stands on the canvas. The standard framing when a stored file lacks it.
  final Framing framing;

  const Clip({
    required this.id,
    required this.media,
    required this.sourceStart,
    required this.duration,
    this.volume = 1,
    this.framing = Framing.standard,
  });

  Clip copyWith({
    ClipID? id,
    MediaID? media,
    Time? sourceStart,
    Time? duration,
    double? volume,
    Framing? framing,
  }) => Clip(
    id: id ?? this.id,
    media: media ?? this.media,
    sourceStart: sourceStart ?? this.sourceStart,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    framing: framing ?? this.framing,
  );

  @override
  bool operator ==(Object other) =>
      other is Clip &&
      other.id == id &&
      other.media == media &&
      other.sourceStart == sourceStart &&
      other.duration == duration &&
      other.volume == volume &&
      other.framing == framing;

  @override
  int get hashCode => Object.hash(id, media, sourceStart, duration, volume, framing);
}

class Project {
  static const int framesPerSecond = 30;

  /// The shape every picture is fitted into.
  final Canvas canvas;

  /// The main track, in order, always touching.
  final List<Clip> clips;

  /// The facts of every media file a clip uses.
  final Map<MediaID, MediaInfo> media;

  /// Starts at 1, each new clip takes it and adds 1.
  final int nextClipID;

  /// In drawing order, the later one on top.
  final List<TextItem> texts;

  /// Starts at 1, each new text takes it and adds 1.
  final int nextTextID;

  /// The sound of every clip, 0 to 1.
  final double clipVolume;
  final bool clipsMuted;

  /// At most one music, which begins at the start of the video.
  final Music? music;

  /// The Swift init(canvas:): no clips, no media, no texts, both next ids 1, clipVolume 1, not muted, no music.
  const Project({this.canvas = Canvas.portrait})
    : clips = const [],
      media = const {},
      nextClipID = 1,
      texts = const [],
      nextTextID = 1,
      clipVolume = 1,
      clipsMuted = false,
      music = null;

  /// The clips, the media and the texts are copied into unmodifiable collections, so a list or map changed
  /// later changes no value, as with Swift's value types.
  Project._({
    required this.canvas,
    required List<Clip> clips,
    required Map<MediaID, MediaInfo> media,
    required this.nextClipID,
    required List<TextItem> texts,
    required this.nextTextID,
    required this.clipVolume,
    required this.clipsMuted,
    required this.music,
  }) : clips = List<Clip>.unmodifiable(clips),
       media = Map<MediaID, MediaInfo>.unmodifiable(media),
       texts = List<TextItem>.unmodifiable(texts);

  /// The sum of the clip lengths.
  Time get duration {
    var sum = Time.zero;
    for (final clip in clips) {
      sum = sum + clip.duration;
    }
    return sum;
  }

  /// The Swift start(of:).
  Time? start(ClipID clip) {
    var start = Time.zero;
    for (final candidate in clips) {
      if (candidate.id == clip) {
        return start;
      }
      start = start + candidate.duration;
    }
    return null;
  }

  /// The Swift clip(at:): the clip whose range holds the time, the later one on a join, none at the end.
  Clip? clip(Time time) {
    var start = Time.zero;
    for (final candidate in clips) {
      final end = start + candidate.duration;
      if (time >= start && time < end) {
        return candidate;
      }
      start = end;
    }
    return null;
  }

  /// The Swift position(of: ClipID): 1 for the first clip.
  int? positionOfClip(ClipID clip) {
    final index = clips.indexWhere((candidate) => candidate.id == clip);
    return index < 0 ? null : index + 1;
  }

  TextItem? text(TextID id) {
    for (final candidate in texts) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }

  /// The Swift position(of: TextID): 1 for the first text of the list.
  int? positionOfText(TextID text) {
    final index = texts.indexWhere((candidate) => candidate.id == text);
    return index < 0 ? null : index + 1;
  }

  /// The Swift range(of:). Whole: zero to the project length. A range is cut at the project end. Null for an
  /// unknown id, for an empty project, and for a range that starts at or after the end.
  TextRange? range(TextID text) {
    final item = this.text(text);
    if (item == null) {
      return null;
    }
    final end = duration;
    return switch (item.span) {
      TextSpanWhole() => end > Time.zero ? TextRange(start: Time.zero, duration: end) : null,
      TextSpanRange(range: final range) =>
        range.start < end ? TextRange(start: range.start, duration: _min(range.duration, end - range.start)) : null,
    };
  }

  /// The smaller of what is left of the file after the start of the music and the project length.
  /// Null with no music and for an empty project.
  Time? get heardMusic {
    final music = this.music;
    if (music == null || clips.isEmpty) {
      return null;
    }
    return _min(music.file.duration - music.start, duration);
  }

  /// The Swift sameFootage(as:). Canvas, the clips compared without their framing, media, clipVolume, clipsMuted
  /// and music are equal. The texts and the framing of the clips may differ.
  bool sameFootage(Project other) =>
      canvas == other.canvas &&
      _listEquals(clips.map(_unframed).toList(), other.clips.map(_unframed).toList()) &&
      _mapEquals(media, other.media) &&
      clipVolume == other.clipVolume &&
      clipsMuted == other.clipsMuted &&
      music == other.music;

  /// The Swift sameTracks(as:). sameFootage with the levels left out: canvas, media, the music's file and start,
  /// and the clips compared without their volume are equal. The volume of the clips, the mute, the clips' volumes,
  /// the music's volume and its fades may differ, and so may the texts.
  bool sameTracks(Project other) {
    if (canvas != other.canvas || !_mapEquals(media, other.media) || clips.length != other.clips.length) {
      return false;
    }
    for (var index = 0; index < clips.length; index++) {
      final mine = clips[index];
      final theirs = other.clips[index];
      if (!(mine.id == theirs.id &&
          mine.media == theirs.media &&
          mine.sourceStart == theirs.sourceStart &&
          mine.duration == theirs.duration)) {
        return false;
      }
    }
    return music?.file == other.music?.file && music?.start == other.music?.start;
  }

  /// "<media raw> <sourceStart ticks>+<duration ticks> <volume times 100, rounded> <v or p>", null for an unknown
  /// id. "v" for a video, "p" for a photo. Digits 0 to 9 in every language. Example: "blue 0+1800 100 v".
  String? clipInfo(ClipID id) {
    Clip? clip;
    for (final candidate in clips) {
      if (candidate.id == id) {
        clip = candidate;
        break;
      }
    }
    if (clip == null) {
      return null;
    }
    final kind = media[clip.media]?.kind == MediaKind.photo ? 'p' : 'v';
    return '${clip.media.raw} ${clip.sourceStart.ticks}+${clip.duration.ticks} ${(clip.volume * 100).round()} $kind';
  }

  /// Music is wrapped in a function so that copyWith can set it to null: `copyWith(music: () => null)`.
  Project copyWith({
    Canvas? canvas,
    List<Clip>? clips,
    Map<MediaID, MediaInfo>? media,
    int? nextClipID,
    List<TextItem>? texts,
    int? nextTextID,
    double? clipVolume,
    bool? clipsMuted,
    Music? Function()? music,
  }) => Project._(
    canvas: canvas ?? this.canvas,
    clips: clips ?? this.clips,
    media: media ?? this.media,
    nextClipID: nextClipID ?? this.nextClipID,
    texts: texts ?? this.texts,
    nextTextID: nextTextID ?? this.nextTextID,
    clipVolume: clipVolume ?? this.clipVolume,
    clipsMuted: clipsMuted ?? this.clipsMuted,
    music: music != null ? music() : this.music,
  );

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.canvas == canvas &&
      _listEquals(other.clips, clips) &&
      _mapEquals(other.media, media) &&
      other.nextClipID == nextClipID &&
      _listEquals(other.texts, texts) &&
      other.nextTextID == nextTextID &&
      other.clipVolume == clipVolume &&
      other.clipsMuted == clipsMuted &&
      other.music == music;

  @override
  int get hashCode => Object.hash(
    canvas,
    Object.hashAll(clips),
    Object.hashAllUnordered(media.entries.map((entry) => Object.hash(entry.key, entry.value))),
    nextClipID,
    Object.hashAll(texts),
    nextTextID,
    clipVolume,
    clipsMuted,
    music,
  );
}

/// The clip with the standard framing, all else kept.
Clip _unframed(Clip clip) => clip.copyWith(framing: Framing.standard);

/// Swift's min: the second when it is less than the first, else the first.
Time _min(Time a, Time b) => b < a ? b : a;

bool _listEquals<T>(List<T> a, List<T> b) {
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

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
