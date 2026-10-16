import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'music_from_video.dart';

/// The part `music` of the sound panel. With no music it offers the button `sound.addMusic` alone. With music it
/// shows the title as given (content, never a key), `state.musicLabel`, the same button under the words of
/// `music.replace`, and the button `sound.removeMusic`. The button opens the system's file browser for one audio
/// file through `pickAudio`. Its one state is the `MusicImport` of a file that comes in: while it is not idle its
/// words show as `sound.importWords`, while it is copying the add buttons are disabled, and after a refusal
/// `sound.importOk` confirms it. Core gives every word and every move. The part copies and reads no file itself: a
/// picked file goes to `importMusic` of the engine through `addMusic`. The rows lay out from leading to trailing,
/// so Arabic mirrors them. The label of the times is fixed left to right, as the time of the preview is.
///
/// https://api.flutter.dev/flutter/widgets/State/mounted.html
/// https://api.flutter.dev/flutter/widgets/Flexible-class.html
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/widgets/Directionality-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class MusicPart extends StatefulWidget {
  const MusicPart({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  State<MusicPart> createState() => _MusicPartState();
}

class _MusicPartState extends State<MusicPart> {
  core.MusicImport _importing = core.MusicImport.idle;

  EditorStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final state = store.state;
    final music = state.project.music;
    final label = state.musicLabel;
    final copying = _importing == core.MusicImport.copying;
    final words = _importing.words;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (music != null)
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    identifier: 'sound.musicTitle',
                    container: true,
                    child: Text(
                      music.file.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
              ),
              if (label != null)
                Semantics(
                  identifier: 'sound.musicLabel',
                  container: true,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 17, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
            ],
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            spacing: 24,
            children: [
              Flexible(
                child: musicButton(
                  widget.words,
                  'sound.addMusic',
                  music == null ? 'music.add' : 'music.replace',
                  copying ? null : _browse,
                ),
              ),
              if (music != null)
                Flexible(
                  // Disabled while copying, as the add button is, so a removal is not undone by the file that
                  // comes in.
                  child: musicButton(
                    widget.words,
                    'sound.removeMusic',
                    'music.remove',
                    copying ? null : () => store.send(core.EditorAction.sound(core.SoundAction.removeMusic)),
                  ),
                ),
              Flexible(child: MusicFromVideo(store: store, words: widget.words, importing: _importing, move: _move)),
            ],
          ),
        ),
        if (words != null)
          Center(
            child: Semantics(
              identifier: 'sound.importWords',
              container: true,
              child: Text(widget.words.text(words), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
            ),
          ),
        if (_importing is core.MusicImportFailed)
          Center(
            child: musicButton(
              widget.words,
              'sound.importOk',
              'music.ok',
              () => _move(core.MusicImportEvent.failureConfirmed),
            ),
          ),
      ],
    );
  }

  /// Moves the state of the import by the event. The part may be gone when a copy ends, after a change of part
  /// or the close of the panel, as m6's state of the part went with it: the event is then dropped.
  void _move(core.MusicImportEvent event) {
    if (!mounted) {
      return;
    }
    setState(() => _importing = _importing.after(event));
  }

  /// Opens the file browser. A browser she cancels, or one that fails, sends no event and changes nothing. A file
  /// she chose sends `picked`, then the event `addMusic` answers for it, with no title.
  Future<void> _browse() async {
    bool chosen;
    try {
      chosen = await store.engine.pickAudio();
    } catch (error) {
      print('music: the file browser failed: $error');
      chosen = false;
    }
    if (!chosen) {
      return;
    }
    _move(core.MusicImportEvent.picked);
    _move(await addMusic(store, () => store.engine.importMusic(store.mediaFolder.path)));
  }
}

/// The one way a file comes in, from the file browser and from a video alike. `copy` copies the file into the
/// media folder of the store and gives the JSON of its music file, then the music is set and the answer is
/// `imported`. When it throws, nothing was set and the answer is `refused`, protected for the code `protectedFile`
/// alone. It throws nothing.
Future<core.MusicImportEvent> addMusic(EditorStore store, Future<String> Function() copy) async {
  try {
    final file = _musicFile(await copy());
    store.send(core.EditorAction.sound(core.SoundAction.setMusic(file)));
    return core.MusicImportEvent.imported;
  } catch (error) {
    print('music: the file was refused: $error');
    return core.MusicImportEvent.refused(error is PlatformException && error.code == 'protectedFile');
  }
}

/// A music file as the engine gives it: the JSON the Swift encoder writes of `MusicFile`.
core.MusicFile _musicFile(String text) {
  final json = jsonDecode(text) as Map<String, Object?>;
  return core.MusicFile(
    id: core.MediaID((json['id']! as Map<String, Object?>)['raw']! as String),
    fileName: json['fileName']! as String,
    title: json['title']! as String,
    duration: core.Time(ticks: ((json['duration']! as Map<String, Object?>)['ticks']! as num).toInt()),
  );
}

/// A button of the part with the words of `key`, its identifier `identifier`, disabled when `tap` is null. Its words
/// may break onto a second line, centred, as m6's do. On iOS Material pads a button to a 48 point target, so the
/// target is shrink wrapped and the height held at 44.
Widget musicButton(WordsText words, String identifier, String key, VoidCallback? tap) {
  final label = words.text(core.Words(key));
  return Semantics(
    identifier: identifier,
    container: true,
    button: true,
    enabled: tap != null,
    label: label,
    onTap: tap,
    excludeSemantics: true,
    child: TextButton(
      onPressed: tap,
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 17),
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
