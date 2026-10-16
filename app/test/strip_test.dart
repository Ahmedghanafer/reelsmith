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

/// The strip and the tools row on the seed three-clips: blue 3 seconds, red 4, green 2, at 60 points a second, on
/// a phone 402 points wide, so the playhead stands at x 201.
late WordsText _english;
late WordsText _arabic;

const Map<String, Object?> _seeded = {'seed': 'three-clips', 'drafts': null};

Future<EditorStore> _show(
  WidgetTester tester, {
  int playhead = 0,
  core.Seed seed = core.Seed.threeClips,
  TextDirection direction = TextDirection.ltr,
  WordsText? words,
}) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = EditorStore(
    state: core.EditorState(seed.project).copyWith(playhead: core.Time(ticks: playhead)),
    mediaFolder: Directory('/fake/Seeds'),
    options: _seeded,
    engine: FakeVideoEngine(),
  );
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: EditorScreen(store: store, words: words ?? _english),
      ),
    ),
  );
  await tester.pump();
  return store;
}

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

Rect _rect(WidgetTester tester, String identifier) => tester.getRect(_id(identifier));

SemanticsNode _node(WidgetTester tester, String identifier) => tester.getSemantics(_id(identifier));

/// A point in the middle of the row of blocks, at x.
Offset _onBlocks(WidgetTester tester, double x) => Offset(x, _rect(tester, 'editor.clip.1').center.dy);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _english = await WordsText.load(const Locale('en'));
    _arabic = await WordsText.load(const Locale('ar'));
  });

  testWidgets('one pointer scrubs and the playhead follows, two pointers change the scale and the playhead stays', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await _show(tester);
    expect(_rect(tester, 'editor.clip.1').width, closeTo(180, 0.5));
    expect(_rect(tester, 'editor.clip.1').left, closeTo(201, 0.5));
    expect(_node(tester, 'editor.playhead').value, '00:00');

    // One pointer: past the slop the strip follows the finger, 60 points to the left are one second later.
    final scrub = await tester.startGesture(_onBlocks(tester, 300));
    for (var step = 0; step < 6; step++) {
      await scrub.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    final before = store.state.playhead.ticks;
    expect(before, greaterThan(0));
    await scrub.moveBy(const Offset(-60, 0));
    await tester.pump();
    final after = store.state.playhead.ticks;
    expect(after - before, closeTo(600, 20));
    await scrub.up();
    await tester.pump();
    // The strip lies under the playhead at its time.
    expect(_rect(tester, 'editor.clip.1').left, closeTo(201 - after / 10, 0.5));
    expect(_node(tester, 'editor.playhead').value, core.Time(ticks: after).clockText);

    // Two pointers apart from 100 to 200 points: the blocks grow, the playhead keeps its time in the middle.
    final first = await tester.startGesture(_onBlocks(tester, 151), pointer: 7);
    final second = await tester.startGesture(_onBlocks(tester, 251), pointer: 8);
    for (var step = 0; step < 10; step++) {
      await first.moveBy(const Offset(-5, 0));
      await second.moveBy(const Offset(5, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pump();
    expect(store.state.playhead.ticks, after);
    final blue = _rect(tester, 'editor.clip.1');
    expect(blue.width, greaterThan(181));
    // At the new scale the time of the playhead is still under the middle.
    expect(blue.left, closeTo(201 - after / 600 * blue.width / 3, 0.5));
    expect(_rect(tester, 'editor.playhead').center.dx, closeTo(201, 0.5));
    semantics.dispose();
  });

  testWidgets('a tap selects a block and leaves the playhead, a tap on empty strip clears the selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await _show(tester, playhead: 2400);
    for (final block in ['editor.clip.1', 'editor.clip.2', 'editor.clip.3']) {
      expect(_node(tester, block), containsSemantics(isSelected: false));
    }

    await tester.tapAt(_rect(tester, 'editor.clip.2').center);
    await tester.pump();
    expect(_node(tester, 'editor.clip.2'), containsSemantics(isSelected: true));
    expect(_node(tester, 'editor.clip.1'), containsSemantics(isSelected: false));
    expect(_node(tester, 'editor.playhead').value, '00:04');

    // Under the row of blocks, inside the strip.
    final strip = _rect(tester, 'editor.timelineRegion');
    await tester.tapAt(Offset(_rect(tester, 'editor.clip.2').center.dx, strip.bottom - 8));
    await tester.pump();
    expect(store.state.selection, isNull);
    expect(_node(tester, 'editor.clip.2'), containsSemantics(isSelected: false));

    // In the band above the row of blocks.
    await tester.tapAt(_rect(tester, 'editor.clip.1').center);
    await tester.pump();
    expect(store.state.selection, isNotNull);
    await tester.tapAt(Offset(_rect(tester, 'editor.clip.1').center.dx, _rect(tester, 'editor.timelineRegion').top + 4));
    await tester.pump();
    expect(store.state.selection, isNull);
    expect(store.state.playhead.ticks, 2400);
    semantics.dispose();
  });

  testWidgets('the zoom starts at the standard when an editor opens', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester);
    final first = await tester.startGesture(_onBlocks(tester, 151), pointer: 7);
    final second = await tester.startGesture(_onBlocks(tester, 251), pointer: 8);
    for (var step = 0; step < 10; step++) {
      await first.moveBy(const Offset(-5, 0));
      await second.moveBy(const Offset(5, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pump();
    expect(_rect(tester, 'editor.clip.1').width, greaterThan(181));

    await tester.pumpWidget(const SizedBox());
    await _show(tester);
    expect(_rect(tester, 'editor.clip.1').width, closeTo(180, 0.5));
    semantics.dispose();
  });

  testWidgets('a split at one second, then a delete of the selected first block, the blocks touching', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await _show(tester, playhead: 600);
    expect(_node(tester, 'editor.split'), containsSemantics(label: 'Split', isButton: true, isEnabled: true));
    expect(_node(tester, 'editor.delete'), containsSemantics(label: 'Delete', isButton: true, isEnabled: false));

    await tester.tap(_id('editor.split'));
    await tester.pump();
    final widths = [60.0, 120.0, 240.0, 120.0];
    for (var index = 0; index < widths.length; index++) {
      final block = _rect(tester, 'editor.clip.${index + 1}');
      expect(block.width, closeTo(widths[index], 0.5));
      if (index > 0) {
        expect(_rect(tester, 'editor.clip.$index').right, closeTo(block.left, 0.5));
      }
    }
    // The last block lies past the right edge of the screen and is still found.
    expect(_rect(tester, 'editor.clip.4').left, greaterThan(402));
    expect(_node(tester, 'editor.clip.4').hasFlag(SemanticsFlag.isHidden), isFalse);
    expect(_node(tester, 'editor.clip.1').label, '1\n00:01');
    expect(_node(tester, 'editor.clip.1').value, store.state.project.clipInfo(store.state.project.clips.first.id));
    expect(_node(tester, 'editor.split'), containsSemantics(isEnabled: false));

    await tester.tapAt(_rect(tester, 'editor.clip.1').center);
    await tester.pump();
    expect(_node(tester, 'editor.clip.1'), containsSemantics(isSelected: true));
    expect(_node(tester, 'editor.delete'), containsSemantics(isEnabled: true));
    await tester.tap(_id('editor.delete'));
    await tester.pump();
    expect(store.state.project.clips.length, 3);
    expect(_id('editor.clip.4'), findsNothing);
    expect(_rect(tester, 'editor.clip.1').width, closeTo(120, 0.5));
    expect(_node(tester, 'editor.delete'), containsSemantics(isEnabled: false));
    semantics.dispose();
  });

  testWidgets(
    'in Arabic the tools row mirrors with all six whole, and the strip, its blocks and the playhead do not',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(tester, playhead: 2700, direction: TextDirection.rtl, words: _arabic);
      final region = _rect(tester, 'editor.toolsRegion');
      final row = ['editor.split', 'editor.delete', 'editor.addText', 'editor.sound', 'editor.addClips', 'editor.frames'];
      for (final identifier in row) {
        final button = _rect(tester, identifier);
        expect(button.left, greaterThanOrEqualTo(region.left), reason: identifier);
        expect(button.right, lessThanOrEqualTo(region.right), reason: identifier);
      }
      // Split leads, which is now on the right, and each button stands left of the one before it.
      for (var index = 1; index < row.length; index++) {
        expect(_rect(tester, row[index]).right, lessThanOrEqualTo(_rect(tester, row[index - 1]).left), reason: row[index]);
      }
      expect(_node(tester, 'editor.split').label, 'تقسيم');
      expect(_node(tester, 'editor.delete').label, 'حذف');

      // Time runs to the right: blue, red, green from left to right, the playhead at 4.5 seconds in the middle.
      expect(_rect(tester, 'editor.clip.1').right, closeTo(_rect(tester, 'editor.clip.2').left, 0.5));
      expect(_rect(tester, 'editor.clip.2').right, closeTo(_rect(tester, 'editor.clip.3').left, 0.5));
      expect(_rect(tester, 'editor.clip.1').left, closeTo(201 - 270, 0.5));
      expect(_rect(tester, 'editor.playhead').center.dx, closeTo(201, 0.5));
      expect(_node(tester, 'editor.playhead').value, '00:04');
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'on iOS the add and the frames button are 44 by 44 points',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(tester);
      // Wide enough for the row in the square letters of the test font, so the row is not scaled down.
      tester.view.physicalSize = const Size(3000, 2622);
      await tester.pump();
      expect(_rect(tester, 'editor.addClips').size, const Size(44, 44));
      expect(_rect(tester, 'editor.frames').size, const Size(44, 44));
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
