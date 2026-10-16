import '../model/project.dart';
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
