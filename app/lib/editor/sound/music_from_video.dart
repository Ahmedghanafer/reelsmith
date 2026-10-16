import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'music_part.dart';

/// The button `sound.addFromVideo` of the part `music`, with the words of `music.fromVideo`. It opens the photo
/// picker for one video through `pick` and takes the sound of the video chosen as the music through
/// `musicFromVideo`, which copies the video, imports its sound with the video's name as the title and removes its
/// copy of the video. It moves the `MusicImport` of the part it stands in: `picked` when a video is chosen, then
/// the event `addMusic` answers. It is disabled while that state is `copying`. A picker closed with nothing chosen,
/// or one that fails, sends no event.
class MusicFromVideo extends StatelessWidget {
  const MusicFromVideo({
    super.key,
    required this.store,
    required this.words,
    required this.importing,
    required this.move,
  });

  final EditorStore store;
  final WordsText words;

  /// The state of the import of the part.
  final core.MusicImport importing;

  /// Moves the state of the import of the part.
  final void Function(core.MusicImportEvent) move;

  @override
  Widget build(BuildContext context) => musicButton(
    words,
    'sound.addFromVideo',
    'music.fromVideo',
    importing == core.MusicImport.copying ? null : _pick,
  );

  Future<void> _pick() async {
    int chosen;
    try {
      chosen = await store.engine.pick(false, 1);
    } catch (error) {
      print('music: the photo picker failed: $error');
      chosen = 0;
    }
    if (chosen == 0) {
      return;
    }
    move(core.MusicImportEvent.picked);
    move(await addMusic(store, () => store.engine.musicFromVideo(store.mediaFolder.path)));
  }
}
