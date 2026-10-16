import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/editor/editor_screen.dart';
import 'package:reelsmith/editor/editor_store.dart';
import 'package:reelsmith/words/words.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import 'support/fake_video_engine.dart';

late WordsText _english;

/// The options `launch` gives on a seeded start.
const Map<String, Object?> _seeded = {'seed': 'two-clips', 'drafts': null};

/// A phone held upright, 402 by 874 points.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<({EditorStore store, FakeVideoEngine engine})> _show(
  WidgetTester tester, {
  core.EditorState? state,
  Map<String, Object?> options = _seeded,
  core.OpenDraft? draft,
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(const SizedBox());
  _phone(tester);
  final engine = FakeVideoEngine();
  final store = EditorStore(
    state: state ?? core.EditorState(core.Seed.twoClips.project),
    mediaFolder: draft?.mediaFolder ?? Directory('/fake/Seeds'),
    options: options,
    engine: engine,
    draft: draft,
  );
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: direction,
        child: EditorScreen(store: store, words: _english),
      ),
    ),
  );
  await tester.pump();
  return (store: store, engine: engine);
}

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

Rect _rect(WidgetTester tester, String identifier) => tester.getRect(_id(identifier));

SemanticsNode _node(WidgetTester tester, String identifier) => tester.getSemantics(_id(identifier));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _english = await WordsText.load(const Locale('en'));
  });

  testWidgets('the regions, the info lines, the picture and the row of play carry their identifiers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester);

    for (final identifier in [
      'editor.root',
      'editor.previewRegion',
      'editor.timelineRegion',
      'editor.toolsRegion',
      'editor.exportRegion',
      'editor.seedInfo',
      'editor.textInfo',
      'editor.faceInfo',
      'editor.soundInfo',
      'editor.picture',
      'editor.projects',
      'editor.play',
      'editor.time',
      'editor.undo',
      'editor.redo',
      'editor.save',
    ]) {
      expect(_id(identifier), findsOneWidget, reason: identifier);
    }
    for (final identifier in ['editor.textRegion', 'editor.soundRegion', 'editor.clipRegion']) {
      expect(_id(identifier), findsNothing, reason: identifier);
    }

    // The regions from top to bottom, the info lines above them.
    final regions = ['editor.previewRegion', 'editor.timelineRegion', 'editor.toolsRegion', 'editor.exportRegion'];
    for (var index = 1; index < regions.length; index++) {
      expect(_rect(tester, regions[index - 1]).top, lessThan(_rect(tester, regions[index]).top));
    }
    expect(_rect(tester, 'editor.seedInfo').top, lessThan(_rect(tester, 'editor.textInfo').top));
    expect(_rect(tester, 'editor.textInfo').top, lessThan(_rect(tester, 'editor.faceInfo').top));
    expect(_rect(tester, 'editor.soundInfo').bottom, lessThanOrEqualTo(_rect(tester, 'editor.previewRegion').top));

    // The picture in the shape of the 9:16 canvas, in the middle of the region, the row under it.
    final region = _rect(tester, 'editor.previewRegion');
    final picture = _rect(tester, 'editor.picture');
    expect(picture.width / picture.height, closeTo(1080 / 1920, 0.01));
    expect(picture.center.dx, closeTo(region.center.dx, 1));
    expect(_rect(tester, 'editor.play').top, greaterThanOrEqualTo(picture.bottom - 1));
    expect(_rect(tester, 'editor.time').top, greaterThanOrEqualTo(picture.bottom - 1));

    expect(_node(tester, 'editor.seedInfo').label, '2 clips, 0 files');
    expect(_node(tester, 'editor.textInfo').label, 'none');
    expect(_node(tester, 'editor.soundInfo').label, '100 . none');
    expect(_node(tester, 'editor.time').label, '00:00 / 00:07');
    expect(_node(tester, 'editor.play'), containsSemantics(label: 'Play', isButton: true, isEnabled: true));
    expect(_node(tester, 'editor.projects'), containsSemantics(label: 'Projects', isButton: true, isEnabled: true));
    expect(_node(tester, 'editor.undo'), containsSemantics(label: 'Undo', isButton: true, isEnabled: false));
    expect(_node(tester, 'editor.redo'), containsSemantics(label: 'Redo', isButton: true, isEnabled: false));
    expect(_node(tester, 'editor.save'), containsSemantics(label: 'Save', isButton: true, isEnabled: true));
    semantics.dispose();
  });

  testWidgets('a tap on play reads Pause, and the empty project has play disabled', (tester) async {
    final semantics = tester.ensureSemantics();
    final (:store, :engine) = await _show(tester);
    await tester.tap(_id('editor.play'));
    await tester.pump();
    expect(store.state.isPlaying, isTrue);
    expect(_node(tester, 'editor.play'), containsSemantics(label: 'Pause', isButton: true, isEnabled: true));

    await _show(tester, state: core.EditorState(core.Seed.empty.project));
    expect(_node(tester, 'editor.time').label, '00:00 / 00:00');
    expect(_node(tester, 'editor.play'), containsSemantics(label: 'Play', isButton: true, isEnabled: false));
    semantics.dispose();
  });

  testWidgets('the text, sound and clip regions show with their state', (tester) async {
    final semantics = tester.ensureSemantics();
    final project = core.Seed.textWide.project;
    await _show(tester, state: core.EditorState(project).copyWith(selectedText: () => core.Seed.textWide.selectedText));
    expect(_id('editor.textRegion'), findsOneWidget);
    expect(_rect(tester, 'editor.toolsRegion').top, lessThan(_rect(tester, 'editor.textRegion').top));
    expect(_rect(tester, 'editor.textRegion').top, lessThan(_rect(tester, 'editor.exportRegion').top));

    await _show(tester, state: core.EditorState(project).copyWith(showsSound: true));
    expect(_id('editor.soundRegion'), findsOneWidget);
    expect(_id('editor.textRegion'), findsNothing);

    await _show(tester, state: core.EditorState(project).copyWith(selection: () => project.clips.first.id));
    expect(_id('editor.clipRegion'), findsOneWidget);
    expect(_id('editor.soundRegion'), findsNothing);
    semantics.dispose();
  });

  testWidgets('without a seed or drafts no info line shows', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, options: const {'seed': null, 'drafts': null});
    for (final identifier in ['editor.seedInfo', 'editor.textInfo', 'editor.faceInfo', 'editor.soundInfo']) {
      expect(_id(identifier), findsNothing, reason: identifier);
    }
    expect(_id('editor.root'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('editor.picture is 0 on a seeded start and then the last buildCount, and has no value without a seed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (:store, :engine) = await _show(tester);
    expect(_node(tester, 'editor.picture').value, '0');
    engine.sendBuildCount(1);
    // The event comes in a microtask after the first pump, and its frame is drawn by the second.
    await tester.pump();
    await tester.pump();
    expect(_node(tester, 'editor.picture').value, '1');
    engine.sendBuildCount(2);
    await tester.pump();
    await tester.pump();
    expect(_node(tester, 'editor.picture').value, '2');

    final unseeded = await _show(tester, options: const {'seed': null, 'drafts': 'kept'});
    unseeded.engine.sendBuildCount(3);
    await tester.pump();
    await tester.pump();
    expect(_node(tester, 'editor.picture').value, '');
    semantics.dispose();
  });

  testWidgets('in Arabic the row of play, the picture and the time stay left to right and the rest mirrors', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, direction: TextDirection.rtl);

    expect(_rect(tester, 'editor.projects').left, lessThan(_rect(tester, 'editor.play').left));
    expect(_rect(tester, 'editor.play').left, lessThan(_rect(tester, 'editor.time').left));
    expect(_rect(tester, 'editor.time').left, lessThan(_rect(tester, 'editor.undo').left));
    expect(_rect(tester, 'editor.undo').left, lessThan(_rect(tester, 'editor.redo').left));
    expect(_rect(tester, 'editor.redo').left, lessThan(_rect(tester, 'editor.save').left));
    final region = _rect(tester, 'editor.previewRegion');
    expect(_rect(tester, 'editor.picture').center.dx, closeTo(region.center.dx, 1));

    for (final identifier in ['editor.picture', 'editor.play', 'editor.time']) {
      expect(Directionality.of(tester.element(_id(identifier))), TextDirection.ltr, reason: identifier);
    }
    for (final identifier in ['editor.root', 'editor.timelineRegion', 'editor.toolsRegion', 'editor.exportRegion']) {
      expect(Directionality.of(tester.element(_id(identifier))), TextDirection.rtl, reason: identifier);
    }
    semantics.dispose();
  });

  testWidgets(
    'on iOS each button of the row is 44 by 44, undo beside redo, Save at the trailing end, and undo and redo follow the history',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final (:store, :engine) = await _show(tester);
      final region = _rect(tester, 'editor.previewRegion');
      for (final identifier in ['editor.projects', 'editor.play', 'editor.undo', 'editor.redo', 'editor.save']) {
        expect(_rect(tester, identifier).size, const Size(44, 44), reason: identifier);
      }
      expect(_rect(tester, 'editor.redo').left - _rect(tester, 'editor.undo').right, closeTo(8, 1));
      expect(_rect(tester, 'editor.save').left, greaterThanOrEqualTo(_rect(tester, 'editor.redo').right - 1));
      expect(_rect(tester, 'editor.save').right, closeTo(region.right, 1));

      store.send(core.EditorAction.trimEnd(store.state.project.clips.last.id, const core.Time(ticks: 600)));
      await tester.pump();
      expect(_node(tester, 'editor.undo'), containsSemantics(isButton: true, isEnabled: true));
      expect(_node(tester, 'editor.redo'), containsSemantics(isButton: true, isEnabled: false));
      await tester.tap(_id('editor.undo'));
      await tester.pump();
      expect(_node(tester, 'editor.undo'), containsSemantics(isButton: true, isEnabled: false));
      expect(_node(tester, 'editor.redo'), containsSemantics(isButton: true, isEnabled: true));
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('the screen takes its colours from the theme, light or dark, and the picture stays on black', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await _show(tester, theme: ThemeData(brightness: brightness));
      final screen = find.byType(EditorScreen);
      expect(tester.widget<Material>(find.descendant(of: screen, matching: find.byType(Material)).first).color, isNull);
      final time = tester.renderObject<RenderParagraph>(find.text('00:00 / 00:07')).text.style!.color!;
      expect(time.computeLuminance() > 0.5, brightness == Brightness.dark, reason: '$brightness');
      final black = find.descendant(of: find.bySemanticsIdentifier('editor.picture'), matching: find.byType(ColoredBox));
      expect(tester.widget<ColoredBox>(black).color, const Color(0xFF000000), reason: '$brightness');
    }
    semantics.dispose();
  });

  group('a draft', () {
    late core.OpenDraft draft;

    setUp(() {
      final folder = Directory.systemTemp.createTempSync('editor_screen');
      addTearDown(() => folder.deleteSync(recursive: true));
      draft = core.DraftShelf(Directory('${folder.path}/Drafts')).create(
        core.Draft(
          project: core.Seed.twoClips.project,
          exportSettings: core.ExportSettings.startChoice,
          changed: DateTime.now(),
        ),
      );
    });

    core.Project written() =>
        core.decodeDraft(File('${draft.shelf.folder.path}/${draft.id.raw}/draft.json').readAsBytesSync()).project;

    core.EditorAction trim(EditorStore store) =>
        core.EditorAction.trimEnd(store.state.project.clips.last.id, const core.Time(ticks: 600));

    testWidgets('is written and gets its cover when the app leaves the active phase', (tester) async {
      final (:store, :engine) = await _show(tester, options: const {'seed': null, 'drafts': null}, draft: draft);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      store.sendDragStep(trim(store));
      expect(store.editing.unsaved, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(store.editing.unsaved, isFalse);
      expect(written(), store.state.project);
      expect(engine.covers, [draft.coverFile.path]);
      expect(store.isOpen, isTrue);

      // The rest of the way out and back makes no second cover. The next leave does.
      for (final phase in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(phase);
      }
      await tester.pump();
      expect(engine.covers, [draft.coverFile.path]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(engine.covers, [draft.coverFile.path, draft.coverFile.path]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('is written, gets its cover and the store closes on a tap of Projects', (tester) async {
      final (:store, :engine) = await _show(tester, options: const {'seed': null, 'drafts': null}, draft: draft);
      store.sendDragStep(trim(store));

      await tester.tap(_id('editor.projects'));
      await tester.pump();
      expect(written(), store.state.project);
      expect(engine.covers, [draft.coverFile.path]);
      expect(store.isOpen, isFalse);
    });

    testWidgets('Save writes, undo and redo step through the history', (tester) async {
      final (:store, :engine) = await _show(tester, options: const {'seed': null, 'drafts': null}, draft: draft);
      final before = store.state.project;
      store.sendDragStep(trim(store));
      await tester.tap(_id('editor.save'));
      await tester.pump();
      expect(written(), store.state.project);
      store.endDrag();
      await tester.pump();

      await tester.tap(_id('editor.undo'));
      await tester.pump();
      expect(store.state.project, before);
      await tester.tap(_id('editor.redo'));
      await tester.pump();
      expect(store.state.project, isNot(before));
    });
  });
}
