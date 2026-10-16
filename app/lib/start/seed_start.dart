import 'dart:io';

import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor/editor_store.dart';
import '../engine/video_engine.dart';

/// The start on a seed: the engine writes the seed's test clips, test tones and test photos once into
/// `<caches>/Seeds/`, keeping a file that is already there, and the store the editor opens with is given, the
/// sound panel open when the seed says so. Null when the launch names no seed. The seed's project is the Dart
/// one, the launch values those `launch` gave: nothing here reads the process arguments. A file that cannot be
/// written is left missing and the editor opens all the same.
/// With `drafts` the seed's project becomes a new draft on the shelf: each file it names is copied from the
/// seeds folder into the draft's media folder, and the store writes to the draft.
///
/// https://api.dart.dev/stable/dart-io/File/copySync.html
Future<EditorStore?> seedStart(VideoEngine engine, Map<String, Object?> options, core.DraftShelf shelf) async {
  final name = options['seed'] as String?;
  final seed = name == null ? null : core.Seed.fromRawValue(name);
  if (seed == null) {
    return null;
  }
  final folder = Directory(await engine.writeSeedMedia(seed.rawValue));
  final project = seed.project;
  var state = core.EditorState(
    project,
  ).copyWith(selectedText: () => seed.selectedText, showsSound: seed.showsSound);
  final playhead = options['playhead'] as num?;
  if (playhead != null) {
    state = core.reduce(state, core.EditorAction.movePlayhead(core.Time(ticks: playhead.toInt())));
  }
  if (options['drafts'] == null) {
    return EditorStore(state: state, mediaFolder: folder, options: options, engine: engine);
  }
  final core.OpenDraft draft;
  try {
    draft = shelf.create(
      core.Draft(project: project, exportSettings: core.ExportSettings.startChoice, changed: DateTime.now()),
    );
  } catch (error) {
    print('seed start: no draft was made, the editor opens on the seed folder: $error');
    return EditorStore(state: state, mediaFolder: folder, options: options, engine: engine);
  }
  for (final file in project.fileNames) {
    try {
      File('${folder.path}/$file').copySync('${draft.mediaFolder.path}/$file');
    } catch (error) {
      print('seed start: $file was not copied into the draft: $error');
    }
  }
  return EditorStore(state: state, mediaFolder: draft.mediaFolder, options: options, engine: engine, draft: draft);
}
