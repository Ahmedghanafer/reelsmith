import '../model/project.dart';
import '../model/sound.dart';
import '../model/text.dart';
import '../model/time.dart';

class EditorState {
  final Project project;
  final ClipID? selection;

  /// A whole frame from zero to the project length.
  final Time playhead;
  final bool isPlaying;

  /// At most one of selection, selectedText and showsSound is set.
  final TextID? selectedText;

  /// The sound panel shows.
  final bool showsSound;

  /// The Swift init(project:): no selection, no sound panel, playhead zero, not playing.
  const EditorState(this.project)
    : selection = null,
      playhead = Time.zero,
      isPlaying = false,
      selectedText = null,
      showsSound = false;

  const EditorState._({
    required this.project,
    required this.selection,
    required this.playhead,
    required this.isPlaying,
    required this.selectedText,
    required this.showsSound,
  });

  /// "<playhead clockText> / <duration clockText>", for example "00:01 / 00:07".
  String get timeLabel => '${playhead.clockText} / ${project.duration.clockText}';

  bool get canPlay => project.clips.isNotEmpty;

  bool get canExport => project.clips.isNotEmpty;

  bool get canAddText => project.clips.isNotEmpty;

  bool get canOpenSound => project.clips.isNotEmpty;

  /// There is music and a step of the start slider fits into its range.
  bool get canSetMusicStart {
    final music = project.music;
    if (music == null) {
      return false;
    }
    return music.largestStart >= SoundGeometry.startStep;
  }

  /// Three fields with one space between them when there is no music: the volume of the clips times 100,
  /// "m" for muted or "." for not, and "none". With music six: the same two, then "<start ticks>+<heard ticks>"
  /// or "hidden" when nothing of it is heard, the volume of the music times 100, and the fade in and the
  /// fade out in ticks, both as stored. Digits and fixed marks, the same in every language.
  String get soundInfo {
    final fields = <String>[_whole(project.clipVolume * 100), project.clipsMuted ? 'm' : '.'];
    final music = project.music;
    if (music == null) {
      fields.add('none');
      return fields.join(' ');
    }
    var heard = 'hidden';
    final length = project.heardMusic;
    if (length != null) {
      heard = '${music.start.ticks}+${length.ticks}';
    }
    fields.add(heard);
    fields.add(_whole(music.volume * 100));
    fields.add('${music.fadeIn.ticks}');
    fields.add('${music.fadeOut.ticks}');
    return fields.join(' ');
  }

  /// "<start>-<end> / <length>" as clock texts: the part of the file that is heard and the length of the file,
  /// for example "00:00-00:07 / 00:10". Null when nothing of the music is heard.
  String? get musicLabel {
    final music = project.music;
    final heard = project.heardMusic;
    if (music == null || heard == null) {
      return null;
    }
    return '${music.start.clockText}-${(music.start + heard).clockText} / ${music.file.duration.clockText}';
  }

  /// "none" with no selected text. Else ten fields with one space between them: the position, the font,
  /// the size, the colour as "r,g,b", the alignment, the centre as "x,y", the rotation, three marks for
  /// outline, shadow and box ("o", "s", "b", or "." for off), the range as "<start ticks>+<duration ticks>"
  /// or "hidden", and the line spacing times 100. Digits and fixed marks, the same in every language.
  String get textInfo {
    final selectedText = this.selectedText;
    final text = selectedText == null ? null : project.text(selectedText);
    final position = selectedText == null ? null : project.positionOfText(selectedText);
    if (selectedText == null || text == null || position == null) {
      return 'none';
    }
    final style = text.style;
    var range = 'hidden';
    final seen = project.range(selectedText);
    if (seen != null) {
      range = '${seen.start.ticks}+${seen.duration.ticks}';
    }
    final fields = <String>[
      '$position',
      style.font.rawValue,
      _whole(style.size),
      '${style.colour.r},${style.colour.g},${style.colour.b}',
      style.align.rawValue,
      '${_whole(text.x)},${_whole(text.y)}',
      _whole(text.rotation),
      '${style.outline ? 'o' : '.'}${style.shadow ? 's' : '.'}${style.box ? 'b' : '.'}',
      range,
      _whole(style.lineSpacing * 100),
    ];
    return fields.join(' ');
  }

  /// The two optional ids are wrapped in a function so that copyWith can set them to null, as Project's music.
  EditorState copyWith({
    Project? project,
    ClipID? Function()? selection,
    Time? playhead,
    bool? isPlaying,
    TextID? Function()? selectedText,
    bool? showsSound,
  }) => EditorState._(
    project: project ?? this.project,
    selection: selection != null ? selection() : this.selection,
    playhead: playhead ?? this.playhead,
    isPlaying: isPlaying ?? this.isPlaying,
    selectedText: selectedText != null ? selectedText() : this.selectedText,
    showsSound: showsSound ?? this.showsSound,
  );

  @override
  bool operator ==(Object other) =>
      other is EditorState &&
      other.project == project &&
      other.selection == selection &&
      other.playhead == playhead &&
      other.isPlaying == isPlaying &&
      other.selectedText == selectedText &&
      other.showsSound == showsSound;

  @override
  int get hashCode => Object.hash(project, selection, playhead, isPlaying, selectedText, showsSound);
}

/// A number rounded to a whole one, written with the digits 0 to 9.
String _whole(double value) => '${value.round()}';
