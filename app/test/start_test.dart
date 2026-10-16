import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/editor/editor_screen.dart';
import 'package:reelsmith/main.dart';
import 'package:reelsmith/start/start_screen.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import 'support/fake_video_engine.dart';

/// The fake with the arguments of the calls the start reads.
class _Engine extends FakeVideoEngine {
  final List<String> seeds = [];
  final List<String> copiedInto = [];
  final List<({bool photos, int limit})> picks = [];

  @override
  Future<String> writeSeedMedia(String seed) {
    seeds.add(seed);
    return super.writeSeedMedia(seed);
  }

  @override
  Future<int> pick(bool photos, int limit) {
    picks.add((photos: photos, limit: limit));
    return super.pick(photos, limit);
  }

  @override
  Future<List<String>> copyPicked(String folder) {
    copiedInto.add(folder);
    return super.copyPicked(folder);
  }
}

/// The fake whose seed media are written when the test completes the future.
class _SlowSeed extends FakeVideoEngine {
  _SlowSeed(this.written);

  final Future<String> written;

  @override
  Future<String> writeSeedMedia(String seed) => written;
}

Directory _temporary() {
  final folder = Directory.systemTemp.createTempSync('start_test');
  addTearDown(() => folder.deleteSync(recursive: true));
  return folder;
}

/// The engine of a launch with these values, the two drafts folders inside `folder`.
_Engine _engine(Directory folder, {String? seed, String? drafts, int? playhead}) => _Engine()
  ..launchAnswer = jsonEncode({
    'drafts': drafts,
    'draftsFolder': '${folder.path}/Drafts',
    'exportFails': false,
    'playhead': playhead,
    'seed': seed,
    'testDraftsFolder': '${folder.path}/TestDrafts',
  });

/// The JSON of a media fact as the Swift encoder writes it.
String _fact(String name) => jsonEncode({
  'duration': {'ticks': 1800},
  'fileName': '$name.mov',
  'hasSound': true,
  'height': 1920,
  'id': {'raw': name},
  'kind': 'video',
  'quarterTurns': 0,
  'width': 1080,
});

/// Starts the root and lets the launch, the words file and a seed start come in.
Future<void> _start(WidgetTester tester, _Engine engine) async {
  await tester.pumpWidget(ReelsmithApp(engine: engine));
  await _settle(tester);
}

/// Real time for the files the test reads and writes, then frames for what came of it.
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 5; round++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

SemanticsNode _node(WidgetTester tester, String identifier) =>
    tester.getSemantics(find.bySemanticsIdentifier(identifier));

void main() {
  // The bundle keeps each words file as the future of the test that read it first, which a later test's
  // clock never runs: each test reads them anew.
  setUp(rootBundle.clear);

  testWidgets('the start screen shows the shape choice and New project with the words of m6, and New project calls pick', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final folder = _temporary();
    final engine = _engine(folder);
    await _start(tester, engine);

    expect(_node(tester, 'start.title'), containsSemantics(label: 'Reelsmith'));
    expect(_node(tester, 'start.landscape'), containsSemantics(label: 'Landscape 16:9', isButton: true, isSelected: true));
    expect(_node(tester, 'start.portrait'), containsSemantics(label: 'Portrait 9:16', isButton: true, isSelected: false));
    expect(
      _node(tester, 'start.newProject'),
      containsSemantics(label: 'New project', isButton: true, hasEnabledState: true, isEnabled: true),
    );
    // The leading shape is first: in English that is the left side.
    expect(
      tester.getRect(find.bySemanticsIdentifier('start.landscape')).left,
      lessThan(tester.getRect(find.bySemanticsIdentifier('start.portrait')).left),
    );

    await tester.tap(find.bySemanticsIdentifier('start.portrait'));
    await tester.pump();
    expect(_node(tester, 'start.portrait'), containsSemantics(isSelected: true));
    expect(_node(tester, 'start.landscape'), containsSemantics(isSelected: false));

    // The picker closes with nothing chosen: the start screen stays as it was, and no draft is made.
    await tester.tap(find.bySemanticsIdentifier('start.newProject'));
    await _settle(tester);
    expect(engine.picks, [(photos: true, limit: 0)]);
    expect(engine.calls, isNot(contains('copyPicked')));
    expect(_node(tester, 'start.newProject'), containsSemantics(isEnabled: true));
    expect(_node(tester, 'start.portrait'), containsSemantics(isSelected: true));
    expect(Directory('${folder.path}/Drafts').existsSync(), isFalse);
    semantics.dispose();
  });

  testWidgets('in Arabic the start screen is mirrored and shows its Arabic words', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.localesTestValue = const [Locale('ar', 'SA')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await _start(tester, _engine(_temporary()));

    expect(Directionality.of(tester.element(find.byType(StartScreen))), TextDirection.rtl);
    expect(_node(tester, 'start.newProject'), containsSemantics(label: 'مشروع جديد'));
    expect(_node(tester, 'start.landscape'), containsSemantics(label: 'أفقي 16:9'));
    expect(
      tester.getRect(find.bySemanticsIdentifier('start.landscape')).left,
      greaterThan(tester.getRect(find.bySemanticsIdentifier('start.portrait')).left),
    );
    semantics.dispose();
  });

  test('the language is the first of English, Arabic and Swedish on her list, English when none is', () {
    expect(language(const [Locale('fr'), Locale('sv', 'SE'), Locale('ar')]), const Locale('sv'));
    expect(language(const [Locale('ar', 'SA'), Locale('en')]), const Locale('ar'));
    expect(language(const [Locale('fr'), Locale('de')]), const Locale('en'));
    expect(language(const []), const Locale('en'));
  });

  testWidgets('the picked clips are copied into a new draft on the chosen shape and the editor opens on them', (
    tester,
  ) async {
    final folder = _temporary();
    final engine = _engine(folder)
      ..pickAnswer = 2
      ..copyPickedAnswer = [_fact('one'), _fact('two')];
    await _start(tester, engine);

    await tester.tap(find.bySemanticsIdentifier('start.portrait'));
    await tester.pump();
    await tester.tap(find.bySemanticsIdentifier('start.newProject'));
    await _settle(tester);

    final shelf = core.DraftShelf(Directory('${folder.path}/Drafts'));
    final summaries = shelf.list();
    expect(summaries, hasLength(1));
    final id = summaries.single.id;
    expect(engine.copiedInto, [shelf.mediaFolder(id).path]);
    final written = core.decodeDraft(File('${folder.path}/Drafts/${id.raw}/draft.json').readAsBytesSync()).project;
    expect(written.canvas, core.Canvas.portrait);
    expect(written.clips, hasLength(2));
    final editor = tester.widget<EditorScreen>(find.byType(EditorScreen));
    expect(editor.store.state.project, written);
    expect(editor.store.draft?.id, id);
  });

  testWidgets('a copy that gives nothing shows the failed state with its words and leaves no draft', (tester) async {
    final semantics = tester.ensureSemantics();
    final folder = _temporary();
    final engine = _engine(folder)..pickAnswer = 1;
    await _start(tester, engine);

    await tester.tap(find.bySemanticsIdentifier('start.newProject'));
    await _settle(tester);
    expect(find.text('None of the clips could be used.'), findsOneWidget);
    expect(_node(tester, 'start.newProject'), containsSemantics(isEnabled: false));
    expect(core.DraftShelf(Directory('${folder.path}/Drafts')).list(), isEmpty);
    expect(find.byType(EditorScreen), findsNothing);

    await tester.tap(find.bySemanticsIdentifier('start.ok'));
    await tester.pump();
    expect(find.text('None of the clips could be used.'), findsNothing);
    expect(_node(tester, 'start.newProject'), containsSemantics(isEnabled: true));
    semantics.dispose();
  });

  testWidgets('the seeded start reads the seed project in Dart, calls writeSeedMedia, and never reads the process arguments', (
    tester,
  ) async {
    final engine = _engine(_temporary(), seed: 'two-clips', playhead: 3000);
    await _start(tester, engine);

    expect(engine.seeds, ['two-clips']);
    final store = tester.widget<EditorScreen>(find.byType(EditorScreen)).store;
    expect(store.state.project, core.Seed.twoClips.project);
    expect(store.state.playhead, const core.Time(ticks: 3000));
    expect(store.mediaFolder.path, '/fake/Seeds');
    expect(store.draft, isNull);
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      expect(file.readAsStringSync(), isNot(contains('executableArguments')), reason: file.path);
    }
  });

  testWidgets('a seeded start with drafts makes its draft on the test drafts folder, a missing file left out', (
    tester,
  ) async {
    final folder = _temporary();
    final seeds = Directory('${folder.path}/Seeds')..createSync();
    File('${seeds.path}/blue.mov').writeAsStringSync('blue');
    final engine = _engine(folder, seed: 'two-clips', drafts: 'kept')..writeSeedMediaAnswer = seeds.path;
    await _start(tester, engine);

    final store = tester.widget<EditorScreen>(find.byType(EditorScreen)).store;
    final draft = store.draft!;
    expect(draft.shelf.folder.path, '${folder.path}/TestDrafts');
    expect(store.mediaFolder.path, draft.mediaFolder.path);
    expect(File('${draft.mediaFolder.path}/blue.mov').readAsStringSync(), 'blue');
    expect(File('${draft.mediaFolder.path}/red.mov').existsSync(), isFalse);
    expect(Directory('${folder.path}/Drafts').existsSync(), isFalse);
  });

  testWidgets('drafts fresh empties the test drafts folder once', (tester) async {
    final folder = _temporary();
    final old = Directory('${folder.path}/TestDrafts/OLD')..createSync(recursive: true);
    await _start(tester, _engine(folder, drafts: 'fresh'));

    expect(old.existsSync(), isFalse);
    expect(find.byType(StartScreen), findsOneWidget);
  });

  testWidgets('a closed store pops back to the start screen and is disposed', (tester) async {
    final engine = _engine(_temporary(), seed: 'two-clips');
    await _start(tester, engine);
    final store = tester.widget<EditorScreen>(find.byType(EditorScreen)).store;

    await store.close();
    await _settle(tester);
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(StartScreen), findsOneWidget);
    expect(engine.calls, contains('disposePreview'));
  });

  testWidgets('a store that comes while an editor is open is disposed, and the editor closes over a page of its own', (
    tester,
  ) async {
    final folder = _temporary();
    final seedWritten = Completer<String>();
    final engine = _SlowSeed(seedWritten.future)
      ..launchAnswer = _engine(folder, seed: 'two-clips').launchAnswer
      ..pickAnswer = 1
      ..copyPickedAnswer = [_fact('one')];
    await _start(tester, engine);

    // New project opens its editor while the seed media are still being written.
    await tester.tap(find.bySemanticsIdentifier('start.newProject'));
    await _settle(tester);
    final opened = tester.widget<EditorScreen>(find.byType(EditorScreen)).store;
    seedWritten.complete('/fake/Seeds');
    await _settle(tester);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(tester.widget<EditorScreen>(find.byType(EditorScreen)).store, same(opened));

    // A page the editor shows over itself goes with it when the store closes.
    unawaited(
      Navigator.of(tester.element(find.byType(EditorScreen))).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
        ),
      ),
    );
    await _settle(tester);
    await opened.close();
    await _settle(tester);
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.byType(StartScreen), findsOneWidget);
  });
}
