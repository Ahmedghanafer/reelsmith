import 'dart:convert';
import 'dart:typed_data';

import '../editor/history.dart';
import '../export/export_settings.dart';
import '../model/canvas.dart';
import '../model/framing.dart';
import '../model/media.dart';
import '../model/project.dart';
import '../model/sound.dart';
import '../model/text.dart';
import '../model/time.dart';
import '../seeds/test_clip.dart';

class DraftID {
  /// A UUID string, the name of the draft's folder.
  final String raw;

  const DraftID(this.raw);

  DraftID copyWith({String? raw}) => DraftID(raw ?? this.raw);

  @override
  bool operator ==(Object other) => other is DraftID && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;
}

/// The stored form of a project: what `draft.json` holds.
class Draft {
  /// The Swift static Draft.version, named apart since a Dart class cannot have a static and an instance member of
  /// one name.
  static const int currentVersion = 1;

  /// currentVersion when made.
  final int version;
  final Project project;
  final ExportSettings exportSettings;

  /// The time of the write. Two drafts are equal when their times are the same moment, as Swift's Date.
  final DateTime changed;

  /// The undo history kept with the draft. Null reads as an empty history, and a file without it reads as null.
  final UndoHistory? history;

  const Draft({required this.project, required this.exportSettings, required this.changed, this.history})
    : version = currentVersion;

  const Draft._({
    required this.version,
    required this.project,
    required this.exportSettings,
    required this.changed,
    required this.history,
  });

  /// History is wrapped in a function so that copyWith can set it to null, as Project's music.
  Draft copyWith({
    int? version,
    Project? project,
    ExportSettings? exportSettings,
    DateTime? changed,
    UndoHistory? Function()? history,
  }) => Draft._(
    version: version ?? this.version,
    project: project ?? this.project,
    exportSettings: exportSettings ?? this.exportSettings,
    changed: changed ?? this.changed,
    history: history != null ? history() : this.history,
  );

  @override
  bool operator ==(Object other) =>
      other is Draft &&
      other.version == version &&
      other.project == project &&
      other.exportSettings == exportSettings &&
      other.changed.microsecondsSinceEpoch == changed.microsecondsSinceEpoch &&
      other.history == history;

  @override
  int get hashCode => Object.hash(version, project, exportSettings, changed.microsecondsSinceEpoch, history);
}

enum DraftError implements Exception {
  /// No draft.json, not the JSON of a Draft, or a version above Draft.currentVersion.
  unreadable,
  cannotWrite,
}

/// JSON with sorted keys and the standard coding of a date: the shapes Swift's JSONEncoder writes for the synthesized
/// Codable of each type (rule 102). A case without values is an object of its name holding an empty object, a value
/// of a case is `_0`, the media are one array of key and value in turn, the date is seconds since 2001-01-01 in UTC,
/// a double, and an optional that is null is left out.
Uint8List encodeDraft(Draft draft) => utf8.encode(jsonEncode(_sorted(_draftJson(draft))));

/// Every failure, and a version above Draft.currentVersion, throws unreadable. A UTF-8 byte order mark at the start
/// is passed over, as Swift's decoder passes it over.
Draft decodeDraft(List<int> data) {
  final marked = data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF;
  final Draft draft;
  try {
    draft = _draft(jsonDecode(utf8.decode(marked ? data.sublist(3) : data)));
  } catch (_) {
    throw DraftError.unreadable;
  }
  if (draft.version > Draft.currentVersion) {
    throw DraftError.unreadable;
  }
  return draft;
}

extension ProjectFileNames on Project {
  /// The file name of every media a clip uses, and of the music, each once, sorted.
  List<String> get fileNames {
    final names = <String>{};
    for (final clip in clips) {
      final info = media[clip.media];
      if (info != null) {
        names.add(info.fileName);
      }
    }
    final music = this.music;
    if (music != null) {
      names.add(music.file.fileName);
    }
    return names.toList()..sort();
  }

  /// Takes out every clip whose media has no facts or whose file name is not in present, every media fact no kept
  /// clip uses, and the music when its file name is not in present. Canvas, texts, ids, volume and mute are kept.
  Project keepingFiles(Set<String> present) {
    final kept = clips.where((clip) {
      final info = media[clip.media];
      return info != null && present.contains(info.fileName);
    }).toList();
    final used = kept.map((clip) => clip.media).toSet();
    final music = this.music;
    return copyWith(
      clips: kept,
      media: {
        for (final entry in media.entries)
          if (used.contains(entry.key)) entry.key: entry.value,
      },
      music: music != null && !present.contains(music.file.fileName) ? () => null : null,
    );
  }
}

/// What the list of drafts shows of one draft.
class DraftSummary {
  final DraftID id;

  /// Null for an unreadable draft.
  final DateTime? changed;

  /// Zero for an unreadable draft.
  final Time duration;
  final int clipCount;
  final int textCount;

  /// Standard for an unreadable draft.
  final ExportSettings exportSettings;
  final bool hasCover;

  DraftSummary({required this.id, required Draft draft, required this.hasCover})
    : changed = draft.changed,
      duration = draft.project.duration,
      clipCount = draft.project.clips.length,
      textCount = draft.project.texts.length,
      exportSettings = draft.exportSettings;

  const DraftSummary._({
    required this.id,
    required this.changed,
    required this.duration,
    required this.clipCount,
    required this.textCount,
    required this.exportSettings,
    required this.hasCover,
  });

  /// The Swift unreadable(_:hasCover:).
  factory DraftSummary.unreadable(DraftID id, {required bool hasCover}) => DraftSummary._(
    id: id,
    changed: null,
    duration: Time.zero,
    clipCount: 0,
    textCount: 0,
    exportSettings: ExportSettings.standard,
    hasCover: hasCover,
  );

  /// Changed is not null.
  bool get isReadable => changed != null;

  /// Changed is wrapped in a function so that copyWith can set it to null, as Project's music.
  DraftSummary copyWith({
    DraftID? id,
    DateTime? Function()? changed,
    Time? duration,
    int? clipCount,
    int? textCount,
    ExportSettings? exportSettings,
    bool? hasCover,
  }) => DraftSummary._(
    id: id ?? this.id,
    changed: changed != null ? changed() : this.changed,
    duration: duration ?? this.duration,
    clipCount: clipCount ?? this.clipCount,
    textCount: textCount ?? this.textCount,
    exportSettings: exportSettings ?? this.exportSettings,
    hasCover: hasCover ?? this.hasCover,
  );

  @override
  bool operator ==(Object other) =>
      other is DraftSummary &&
      other.id == id &&
      other.changed?.microsecondsSinceEpoch == changed?.microsecondsSinceEpoch &&
      other.duration == duration &&
      other.clipCount == clipCount &&
      other.textCount == textCount &&
      other.exportSettings == exportSettings &&
      other.hasCover == hasCover;

  @override
  int get hashCode => Object.hash(
    id,
    changed?.microsecondsSinceEpoch,
    duration,
    clipCount,
    textCount,
    exportSettings,
    hasCover,
  );
}

/// "2026-10-14 21:05": the Gregorian calendar, 24 hours, the digits 0 to 9 in every language. The Swift
/// dateText(_:in:) with the two zones Dart knows: UTC when inUtc, else the phone's own zone.
String dateText(DateTime moment, {required bool inUtc}) {
  final date = inUtc ? moment.toUtc() : moment.toLocal();
  String padded(int value, int width) => value.toString().padLeft(width, '0');
  return '${padded(date.year, 4)}-${padded(date.month, 2)}-${padded(date.day, 2)} '
      '${padded(date.hour, 2)}:${padded(date.minute, 2)}';
}

/// The count, then one field for each summary in its order, one space between them. A readable one is
/// "<clips>+<duration ticks>+<texts>+<shortSide>x<framesPerSecond>+<c or .>", c when it has a cover.
/// An unreadable one is "x". "0" for none. Example: "2 1+1800+1+720x60+c 2+4200+0+1080x30+.".
String draftsInfo(List<DraftSummary> summaries) {
  final fields = ['${summaries.length}'];
  for (final summary in summaries) {
    if (!summary.isReadable) {
      fields.add('x');
      continue;
    }
    fields.add(
      '${summary.clipCount}+${summary.duration.ticks}+${summary.textCount}+'
      '${summary.exportSettings.size.shortSide}x${summary.exportSettings.rate.framesPerSecond}+'
      '${summary.hasCover ? 'c' : '.'}',
    );
  }
  return fields.join(' ');
}

// The writing side of the codec. Each function gives the JSON value Swift's synthesized encode(to:) gives its type.

/// Microseconds from 1970-01-01 to 2001-01-01, Swift's reference date, both in UTC.
const int _referenceMicroseconds = 978307200000000;

/// The keys of every object sorted, as the Swift encoder's sortedKeys writes them.
Object? _sorted(Object? json) => switch (json) {
  Map<String, Object?>() => {for (final key in json.keys.toList()..sort()) key: _sorted(json[key])},
  List<Object?>() => [for (final item in json) _sorted(item)],
  _ => json,
};

/// A case without values: an object of its name holding an empty object.
Map<String, Object?> _bare(String name) => {name: <String, Object?>{}};

/// A case with one value: an object of its name holding the value as `_0`.
Map<String, Object?> _valued(String name, Object? value) => {
  name: {'_0': value},
};

Map<String, Object?> _timeJson(Time time) => {'ticks': time.ticks};

Map<String, Object?> _draftJson(Draft draft) {
  final history = draft.history;
  return {
    'version': draft.version,
    'project': _projectJson(draft.project),
    'exportSettings': {'size': _bare(draft.exportSettings.size.name), 'rate': _bare(draft.exportSettings.rate.name)},
    'changed': (draft.changed.microsecondsSinceEpoch - _referenceMicroseconds) / 1000000,
    if (history != null) 'history': _historyJson(history),
  };
}

Map<String, Object?> _projectJson(Project project) {
  final music = project.music;
  return {
    'canvas': _bare(project.canvas.name),
    'clips': [for (final clip in project.clips) _clipJson(clip)],
    'media': [
      for (final entry in project.media.entries) ...[
        {'raw': entry.key.raw},
        _mediaInfoJson(entry.value),
      ],
    ],
    'nextClipID': project.nextClipID,
    'texts': [for (final text in project.texts) _textJson(text)],
    'nextTextID': project.nextTextID,
    'clipVolume': project.clipVolume,
    'clipsMuted': project.clipsMuted,
    if (music != null) 'music': _musicJson(music),
  };
}

Map<String, Object?> _clipJson(Clip clip) => {
  'id': {'raw': clip.id.raw},
  'media': {'raw': clip.media.raw},
  'sourceStart': _timeJson(clip.sourceStart),
  'duration': _timeJson(clip.duration),
  'volume': clip.volume,
  'framing': {
    'fit': clip.framing.fit.rawValue,
    'backdrop': clip.framing.backdrop.rawValue,
    'zoom': clip.framing.zoom,
    'x': clip.framing.x,
    'y': clip.framing.y,
  },
};

Map<String, Object?> _mediaInfoJson(MediaInfo info) => {
  'id': {'raw': info.id.raw},
  'fileName': info.fileName,
  'width': info.width,
  'height': info.height,
  'duration': _timeJson(info.duration),
  'quarterTurns': info.quarterTurns,
  'hasSound': info.hasSound,
  'kind': info.kind.rawValue,
};

Map<String, Object?> _textJson(TextItem text) => {
  'id': {'raw': text.id.raw},
  'string': text.string,
  'span': switch (text.span) {
    TextSpanWhole() => _bare('whole'),
    TextSpanRange(:final range) => _valued('range', {
      'start': _timeJson(range.start),
      'duration': _timeJson(range.duration),
    }),
  },
  'x': text.x,
  'y': text.y,
  'rotation': text.rotation,
  'style': {
    'font': text.style.font.rawValue,
    'size': text.style.size,
    'colour': {'r': text.style.colour.r, 'g': text.style.colour.g, 'b': text.style.colour.b},
    'align': text.style.align.rawValue,
    'lineSpacing': text.style.lineSpacing,
    'outline': text.style.outline,
    'shadow': text.style.shadow,
    'box': text.style.box,
  },
};

Map<String, Object?> _musicJson(Music music) => {
  'file': {
    'id': {'raw': music.file.id.raw},
    'fileName': music.file.fileName,
    'title': music.file.title,
    'duration': _timeJson(music.file.duration),
  },
  'start': _timeJson(music.start),
  'volume': music.volume,
  'fadeIn': _timeJson(music.fadeIn),
  'fadeOut': _timeJson(music.fadeOut),
};

Map<String, Object?> _historyJson(UndoHistory history) {
  final run = history.run;
  return {
    'past': [for (final project in history.past) _projectJson(project)],
    'future': [for (final project in history.future) _projectJson(project)],
    if (run != null)
      'run': switch (run) {
        EditRunTyping(:final id) => _valued('typing', {'raw': id.raw}),
        EditRunShaping(:final id) => _valued('shaping', {'raw': id.raw}),
        EditRunDrag() => _bare('drag'),
      },
  };
}

// The reading side. Each function reads what Swift's synthesized init(from:) reads, and throws where it throws: a
// missing key or a null where a value is needed, a value of another type, a byte out of 0 to 255, an unknown case.

Map<String, Object?> _object(Object? json) => json as Map<String, Object?>;

double _double(Object? json) => (json as num).toDouble();

/// Missing or null reads as null, as decodeIfPresent reads it.
T? _optional<T>(Map<String, Object?> object, String key, T Function(Object?) read) {
  final value = object[key];
  return value == null ? null : read(value);
}

/// The one case a Swift enum with values is written as: of the keys that name a case there must be exactly one, and
/// it holds an object. Keys that name no case are passed over, as Swift passes them over.
(String, Map<String, Object?>) _case(Object? json, Iterable<String> names) {
  final object = _object(json);
  final keys = object.keys.where(names.contains).toList();
  if (keys.length != 1) {
    throw const FormatException('not one case');
  }
  return (keys.single, _object(object[keys.single]));
}

/// A Swift enum without values, read as a Dart enum of the same case names.
T _bareCase<T extends Enum>(Object? json, List<T> values) =>
    values.byName(_case(json, values.map((value) => value.name)).$1);

/// A Swift enum with a String raw value.
T _rawCase<T>(Object? json, List<T> values, String Function(T) rawValue) {
  final raw = json as String;
  return values.firstWhere((value) => rawValue(value) == raw);
}

/// Swift's Int and Int64: any JSON number of a whole value (`1800`, `1800.0`, `1.8e3`), never a fraction.
int _int(Object? json) {
  final number = json as num;
  if (number is int) {
    return number;
  }
  if (!number.isFinite || number != number.truncateToDouble() || number.abs() >= 9223372036854775808.0) {
    throw const FormatException('not a whole number');
  }
  return number.toInt();
}

/// Swift's UInt8.
int _byte(Object? json) {
  final value = _int(json);
  if (value < 0 || value > 255) {
    throw const FormatException('not a byte');
  }
  return value;
}

Time _time(Object? json) => Time(ticks: _int(_object(json)['ticks']));

MediaID _mediaID(Object? json) => MediaID(_object(json)['raw'] as String);

ClipID _clipID(Object? json) => ClipID(_int(_object(json)['raw']));

TextID _textID(Object? json) => TextID(_int(_object(json)['raw']));

Draft _draft(Object? json) {
  final object = _object(json);
  final settings = _object(object['exportSettings']);
  return Draft._(
    version: _int(object['version']),
    project: _project(object['project']),
    exportSettings: ExportSettings(
      size: _bareCase(settings['size'], ExportSize.values),
      rate: _bareCase(settings['rate'], ExportRate.values),
    ),
    changed: DateTime.fromMicrosecondsSinceEpoch(
      (_double(object['changed']) * 1000000).round() + _referenceMicroseconds,
      isUtc: true,
    ),
    history: _optional(object, 'history', _history),
  );
}

Project _project(Object? json) {
  final object = _object(json);
  final pairs = object['media'] as List<Object?>;
  if (pairs.length.isOdd) {
    throw const FormatException('a media key without its value');
  }
  final media = <MediaID, MediaInfo>{};
  for (var index = 0; index < pairs.length; index += 2) {
    media[_mediaID(pairs[index])] = _mediaInfo(pairs[index + 1]);
  }
  return Project(canvas: _bareCase(object['canvas'], Canvas.values)).copyWith(
    clips: [for (final clip in object['clips'] as List<Object?>) _clip(clip)],
    media: media,
    nextClipID: _int(object['nextClipID']),
    texts: [for (final text in object['texts'] as List<Object?>) _text(text)],
    nextTextID: _int(object['nextTextID']),
    clipVolume: _double(object['clipVolume']),
    clipsMuted: object['clipsMuted'] as bool,
    music: () => _optional(object, 'music', _music),
  );
}

/// A file written before volume existed reads as 1, and one written before framing existed as the standard framing.
Clip _clip(Object? json) {
  final object = _object(json);
  return Clip(
    id: _clipID(object['id']),
    media: _mediaID(object['media']),
    sourceStart: _time(object['sourceStart']),
    duration: _time(object['duration']),
    volume: _optional(object, 'volume', _double) ?? 1,
    framing: _optional(object, 'framing', _framing) ?? Framing.standard,
  );
}

Framing _framing(Object? json) {
  final object = _object(json);
  return Framing(
    fit: _rawCase(object['fit'], Fit.values, (fit) => fit.rawValue),
    backdrop: _rawCase(object['backdrop'], Backdrop.values, (backdrop) => backdrop.rawValue),
    zoom: _double(object['zoom']),
    x: _double(object['x']),
    y: _double(object['y']),
  );
}

/// A file written before kind existed reads as a video.
MediaInfo _mediaInfo(Object? json) {
  final object = _object(json);
  return MediaInfo(
    id: _mediaID(object['id']),
    fileName: object['fileName'] as String,
    width: _int(object['width']),
    height: _int(object['height']),
    duration: _time(object['duration']),
    quarterTurns: _int(object['quarterTurns']),
    hasSound: object['hasSound'] as bool,
    kind: _optional(object, 'kind', (kind) => _rawCase(kind, MediaKind.values, (value) => value.rawValue)) ??
        MediaKind.video,
  );
}

TextItem _text(Object? json) {
  final object = _object(json);
  final (spanCase, spanObject) = _case(object['span'], const ['whole', 'range']);
  final style = _object(object['style']);
  final colour = _object(style['colour']);
  return TextItem(
    id: _textID(object['id']),
    string: object['string'] as String,
    span: spanCase == 'whole' ? TextSpan.whole : TextSpan.range(_textRange(spanObject['_0'])),
    x: _double(object['x']),
    y: _double(object['y']),
    rotation: _double(object['rotation']),
    style: TextStyle(
      font: _rawCase(style['font'], TextFont.values, (font) => font.rawValue),
      size: _double(style['size']),
      colour: RGB(r: _byte(colour['r']), g: _byte(colour['g']), b: _byte(colour['b'])),
      align: _rawCase(style['align'], TextAlign.values, (align) => align.rawValue),
      lineSpacing: _double(style['lineSpacing']),
      outline: style['outline'] as bool,
      shadow: style['shadow'] as bool,
      box: style['box'] as bool,
    ),
  );
}

TextRange _textRange(Object? json) {
  final object = _object(json);
  return TextRange(start: _time(object['start']), duration: _time(object['duration']));
}

Music _music(Object? json) {
  final object = _object(json);
  final file = _object(object['file']);
  return Music(
    file: MusicFile(
      id: _mediaID(file['id']),
      fileName: file['fileName'] as String,
      title: file['title'] as String,
      duration: _time(file['duration']),
    ),
    start: _time(object['start']),
    volume: _double(object['volume']),
    fadeIn: _time(object['fadeIn']),
    fadeOut: _time(object['fadeOut']),
  );
}

UndoHistory _history(Object? json) {
  final object = _object(json);
  return const UndoHistory().copyWith(
    past: [for (final project in object['past'] as List<Object?>) _project(project)],
    future: [for (final project in object['future'] as List<Object?>) _project(project)],
    run: () => _optional(object, 'run', _run),
  );
}

EditRun _run(Object? json) {
  final (name, object) = _case(json, const ['typing', 'shaping', 'drag']);
  return switch (name) {
    'typing' => EditRun.typing(_textID(object['_0'])),
    'shaping' => EditRun.shaping(_textID(object['_0'])),
    _ => EditRun.drag,
  };
}
