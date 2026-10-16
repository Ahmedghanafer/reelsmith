import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/editor/editor_store.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import 'support/fake_video_engine.dart';

/// The project of the seed two-clips: blue for 3 seconds, then red for 4.
core.Project get _seedProject => core.Seed.twoClips.project;

/// An edit that changes the project: the end of the last clip one second shorter.
core.EditorAction get _trim => core.EditorAction.trimEnd(_seedProject.clips.last.id, const core.Time(ticks: 600));

core.Project _written(core.OpenDraft draft) =>
    core.decodeDraft(File('${draft.shelf.folder.path}/${draft.id.raw}/draft.json').readAsBytesSync()).project;

/// A store on a new draft of the seed in a temporary folder, its texture made.
Future<({EditorStore store, FakeVideoEngine engine, core.OpenDraft draft})> _open(WidgetTester tester) async {
  final folder = Directory.systemTemp.createTempSync('m7-16-editor-store');
  addTearDown(() => folder.deleteSync(recursive: true));
  final draft = core.DraftShelf(Directory('${folder.path}/Drafts')).create(
    core.Draft(project: _seedProject, exportSettings: core.ExportSettings.startChoice, changed: DateTime.now()),
  );
  final engine = FakeVideoEngine();
  final store = EditorStore(
    state: core.EditorState(_seedProject),
    mediaFolder: draft.mediaFolder,
    options: const {},
    engine: engine,
    draft: draft,
  );
  addTearDown(store.dispose);
  await tester.pump();
  return (store: store, engine: engine, draft: draft);
}

void main() {
  testWidgets('an edit, an undo and a redo each write the draft', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    final before = store.state.project;

    store.send(_trim);
    expect(store.state.project, isNot(before));
    expect(_written(draft), store.state.project.withoutBlankTexts);
    expect(store.editing.unsaved, isFalse);

    store.undo();
    expect(_written(draft), before);
    expect(store.editing.unsaved, isFalse);

    store.redo();
    expect(_written(draft), store.state.project.withoutBlankTexts);
    expect(store.state.project, isNot(before));
    expect(store.editing.unsaved, isFalse);
  });

  testWidgets('a drag writes when it ends, and Save writes at once while a run is open', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    final before = store.state.project;

    store.sendDragStep(_trim);
    expect(_written(draft), before);
    expect(store.editing.unsaved, isTrue);
    store.endDrag();
    expect(_written(draft), store.state.project);
    expect(store.editing.unsaved, isFalse);

    store.sendDragStep(_trim);
    expect(store.editing.history.run, core.EditRun.drag);
    store.write();
    expect(_written(draft), store.state.project);
    expect(store.editing.unsaved, isFalse);
  });

  testWidgets('a leave writes, makes the cover and closes', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    store.sendDragStep(_trim);
    expect(store.isOpen, isTrue);

    await store.close();
    expect(_written(draft), store.state.project);
    expect(engine.covers, [draft.coverFile.path]);
    expect(store.isOpen, isFalse);
  });

  testWidgets('a leave whose cover throws still closes', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    engine.writeCoverError = Exception('no cover');
    store.send(_trim);

    await store.close();
    expect(engine.calls, contains('writeCover'));
    expect(store.isOpen, isFalse);
  });

  testWidgets('a write that fails leaves the draft unsaved, and a start without a draft writes nothing', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('m7-16-editor-store');
    addTearDown(() => folder.deleteSync(recursive: true));
    final gone = core.OpenDraft(shelf: core.DraftShelf(Directory('${folder.path}/missing')), id: const core.DraftID('x'));
    final failing = EditorStore(
      state: core.EditorState(_seedProject),
      mediaFolder: folder,
      options: const {},
      engine: FakeVideoEngine(),
      draft: gone,
    );
    addTearDown(failing.dispose);
    failing.send(_trim);
    expect(failing.editing.unsaved, isTrue);

    final seeded = EditorStore(
      state: core.EditorState(_seedProject),
      mediaFolder: folder,
      options: const {},
      engine: FakeVideoEngine(),
    );
    addTearDown(seeded.dispose);
    seeded.send(_trim);
    expect(seeded.editing.unsaved, isTrue);
    expect(folder.listSync(), isEmpty);
  });

  testWidgets('the shelf is opened on the folder launch gives', (tester) async {
    final launch = jsonDecode(FakeVideoEngine().launchAnswer) as Map<String, Object?>;
    expect(draftShelf(launch).folder.path, '/fake/Drafts');
    expect(draftShelf({...launch, 'drafts': 'fresh'}).folder.path, '/fake/TestDrafts');
  });

  testWidgets('the first show comes with the texture and the store playhead', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    expect(engine.calls.take(2).toList(), ['createPreview', 'show']);
    expect(store.textureId, engine.createPreviewAnswer);
    final first = engine.shows.single;
    expect(first.textureId, engine.createPreviewAnswer);
    expect(first.mediaFolder, draft.mediaFolder.path);
    expect(first.playhead, 0);
    expect(first.playing, isFalse);
    expect(((jsonDecode(first.project) as Map<String, Object?>)['clips']! as List).length, 2);
  });

  testWidgets('a change of the project is shown without a playhead, a selection shows nothing', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    store.send(core.EditorAction.select(_seedProject.clips.first.id));
    expect(engine.shows, hasLength(1));

    store.send(_trim);
    expect(engine.shows, hasLength(2));
    expect(engine.shows.last.playhead, isNull);
    expect(((jsonDecode(engine.shows.last.project) as Map<String, Object?>)['clips']! as List).length, 2);
  });

  testWidgets('a playhead Dart moved is sent, and play from the end sends zero', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    final length = store.state.project.duration;

    store.send(core.EditorAction.movePlayhead(length));
    expect(engine.shows.last.playhead, length.ticks);
    expect(engine.shows.last.playing, isFalse);

    store.send(core.EditorAction.play);
    expect(store.state.playhead, core.Time.zero);
    expect(engine.shows.last.playhead, 0);
    expect(engine.shows.last.playing, isTrue);
  });

  testWidgets('an edit that clamps the playhead sends it', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    store.send(core.EditorAction.movePlayhead(store.state.project.duration));

    store.send(_trim);
    expect(store.state.playhead, store.state.project.duration);
    expect(engine.shows.last.playhead, store.state.project.duration.ticks);
  });

  testWidgets('a playhead event is never sent back, a pause sends the store playhead, a later one is dropped', (
    tester,
  ) async {
    final (:store, :engine, :draft) = await _open(tester);
    store.send(core.EditorAction.play);
    final shown = engine.shows.length;

    engine.sendPlayhead(600);
    await tester.pump();
    expect(store.state.playhead, const core.Time(ticks: 600));
    expect(engine.shows, hasLength(shown));

    store.send(core.EditorAction.pause);
    expect(engine.shows, hasLength(shown + 1));
    expect(engine.shows.last.playhead, 600);
    expect(engine.shows.last.playing, isFalse);

    engine.sendPlayhead(900);
    await tester.pump();
    expect(store.state.playhead, const core.Time(ticks: 600));
    expect(engine.shows, hasLength(shown + 1));
  });

  testWidgets('an undo while playing sends the playhead it keeps', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    store.send(_trim);
    store.send(core.EditorAction.play);
    engine.sendPlayhead(600);
    await tester.pump();

    store.undo();
    expect(store.state.isPlaying, isFalse);
    expect(engine.shows.last.playhead, 600);
    expect(engine.shows.last.playing, isFalse);
  });

  testWidgets('played to end pauses on the end, and a second one in a row changes nothing', (tester) async {
    final (:store, :engine, :draft) = await _open(tester);
    final length = store.state.project.duration;
    store.send(core.EditorAction.play);

    engine.sendPlayedToEnd();
    await tester.pump();
    expect(store.state.isPlaying, isFalse);
    expect(store.state.playhead, length);
    expect(engine.shows.last.playhead, length.ticks);
    expect(engine.shows.last.playing, isFalse);
    final shown = engine.shows.length;
    final state = store.state;

    engine.sendPlayedToEnd();
    await tester.pump();
    expect(engine.shows, hasLength(shown));
    expect(store.state, state);
  });
}
