import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/text_model_test.dart' show arabicLine, arabicLineScalars;

// testATextPastAShortenedProjectKeepsItsValuesAndComesBack calls renderPlan and stays in Swift.

void main() {
  const one = TextID(1);
  const blue = ClipID(1);
  const red = ClipID(2);
  final wide = EditorState(Seed.twoClipsWide.project);
  final tall = EditorState(Seed.twoClips.project);
  final textWide = EditorState(Seed.textWide.project);
  final textBoxWide = EditorState(Seed.textBoxWide.project);

  void assertValid(EditorState state, String step) {
    final project = state.project;
    final ids = project.texts.map((text) => text.id).toList();
    expect(ids.toSet().length, ids.length, reason: '$step: a text id is used twice');
    for (final text in project.texts) {
      final span = text.span;
      if (span is TextSpanRange) {
        final range = span.range;
        expect(range.start >= Time.zero, isTrue, reason: '$step: the start of a range');
        expect(range.start.ticks.remainder(Time.frame.ticks), 0, reason: '$step: the start of a range');
        expect(range.duration.ticks.remainder(Time.frame.ticks), 0, reason: '$step: the length of a range');
        expect(range.duration >= TextGeometry.minimumText, isTrue, reason: '$step: the length of a range');
      }
      expect(text.style.size, greaterThanOrEqualTo(16), reason: '$step: the size');
      expect(text.style.size, lessThanOrEqualTo(400), reason: '$step: the size');
      expect(text.x, greaterThanOrEqualTo(0), reason: '$step: the centre');
      expect(text.x, lessThanOrEqualTo(project.canvas.width), reason: '$step: the centre');
      expect(text.y, greaterThanOrEqualTo(0), reason: '$step: the centre');
      expect(text.y, lessThanOrEqualTo(project.canvas.height), reason: '$step: the centre');
      expect(text.rotation, greaterThan(-180), reason: '$step: the rotation');
      expect(text.rotation, lessThanOrEqualTo(180), reason: '$step: the rotation');
      if (text.isBlank) {
        expect(state.selectedText, text.id, reason: '$step: a blank text that is not selected');
      }
    }
    final selected = state.selectedText;
    if (selected != null) {
      expect(project.text(selected), isNotNull, reason: '$step: the selected text is not in the project');
    }
    expect(state.selection != null && state.selectedText != null, isFalse, reason: '$step: two selections');
  }

  /// Sends the actions one by one. The state must be valid after each.
  EditorState send(EditorState state, List<EditorAction> actions) {
    var next = state;
    for (final action in actions) {
      next = reduce(next, action);
      assertValid(next, 'after $action');
    }
    return next;
  }

  EditorState sendText(EditorState state, List<TextAction> actions) {
    var next = state;
    for (final action in actions) {
      next = reduce(next, EditorAction.text(action));
      assertValid(next, 'after $action');
    }
    return next;
  }

  EditorState playing(EditorState state) => state.copyWith(isPlaying: true);

  /// The state of a two clip seed with its red clip deleted and its blue clip cut to the length.
  EditorState shortened(EditorState state, int ticks) => send(state, [
    EditorAction.select(red),
    EditorAction.deleteSelected,
    EditorAction.trimEnd(blue, Time(ticks: 1800 - ticks)),
  ]);

  TextSpan range(int start, int duration) =>
      TextSpan.range(TextRange(start: Time(ticks: start), duration: Time(ticks: duration)));

  TextSpan? span(EditorState state) => state.project.text(one)?.span;

  TextSpan? afterTrimStart(EditorState state, int ticks) =>
      span(sendText(state, [TextAction.trimStart(one, Time(ticks: ticks))]));

  TextSpan? afterTrimEnd(EditorState state, int ticks) =>
      span(sendText(state, [TextAction.trimEnd(one, Time(ticks: ticks))]));

  double? sizeAfter(double size) {
    final style = TextStyle.standard.copyWith(size: size);
    return sendText(textWide, [TextAction.setStyle(one, style)]).project.text(one)?.style.size;
  }

  double? spacingAfter(double spacing) {
    final style = TextStyle.standard.copyWith(lineSpacing: spacing);
    return sendText(textWide, [TextAction.setStyle(one, style)]).project.text(one)?.style.lineSpacing;
  }

  /// The centre of text 1 after a move, as x then y.
  List<double> centreAfter(EditorState state, double x, double y) {
    final text = sendText(state, [TextAction.move(one, x, y)]).project.text(one);
    return [text?.x ?? -1, text?.y ?? -1];
  }

  double? angleAfter(double angle) => sendText(textWide, [TextAction.turn(one, angle)]).project.text(one)?.rotation;

  // Add

  test('testAddPutsOneStandardTextInTheMiddleOfTheCanvasAndSelectsIt', () {
    final start = playing(wide).copyWith(selection: () => blue);

    final next = sendText(start, [TextAction.add]);

    expect(next.project.texts, [
      const TextItem(id: one, string: '', span: TextSpan.whole, x: 960, y: 540, rotation: 0, style: TextStyle.standard),
    ]);
    expect(next.project.texts.first.style.size, 64);
    expect(next.selectedText, one);
    expect(next.selection, isNull);
    expect(next.project.nextTextID, 2);
    expect(next.isPlaying, isFalse);
  });

  test('testAddOnThePortraitCanvasPutsTheTextInItsMiddle', () {
    final next = sendText(tall, [TextAction.add]);

    expect(next.project.texts.map((text) => [text.x, text.y]).toList(), [
      [540, 960],
    ]);
  });

  test('testAddOnAnEmptyProjectChangesNothing', () {
    final empty = playing(EditorState(Seed.empty.project));

    expect(sendText(empty, [TextAction.add]), empty);
  });

  test('testASecondTextIsTheLastOfTheListWithId2', () {
    final next = sendText(wide, [TextAction.add, TextAction.setString(one, 'a'), TextAction.add]);

    expect(next.project.texts.map((text) => text.id).toList(), [one, const TextID(2)]);
    expect(next.selectedText, const TextID(2));
    expect(next.project.nextTextID, 3);
  });

  test('testAnIdIsNotUsedAgainAfterADelete', () {
    final next = send(wide, [
      EditorAction.text(TextAction.add),
      EditorAction.deleteSelected,
      EditorAction.text(TextAction.add),
    ]);

    expect(next.project.texts.map((text) => text.id).toList(), [const TextID(2)]);
    expect(next.project.nextTextID, 3);
  });

  // Select

  test('testSelectSetsTheSelectedTextClearsTheClipAndLeavesPlayingAlone', () {
    final start = textWide.copyWith(selection: () => blue);

    final paused = sendText(start, [TextAction.select(one)]);
    final played = sendText(playing(start), [TextAction.select(one)]);

    expect(paused.selectedText, one);
    expect(paused.selection, isNull);
    expect(paused.isPlaying, isFalse);
    expect(played.selectedText, one);
    expect(played.selection, isNull);
    expect(played.isPlaying, isTrue);
  });

  test('testSelectOfAnUnknownTextChangesNothing', () {
    final start = textWide.copyWith(selection: () => blue);

    expect(sendText(start, [TextAction.select(const TextID(99))]), start);
  });

  // The blank rule

  test('testABlankTextGoesWhenTheSelectionIsCleared', () {
    final next = send(wide, [EditorAction.text(TextAction.add), EditorAction.clearSelection]);

    expect(next.project.texts, isEmpty);
    expect(next.selectedText, isNull);
  });

  test('testABlankTextGoesWhenAClipIsSelected', () {
    final next = send(wide, [EditorAction.text(TextAction.add), EditorAction.select(blue)]);

    expect(next.project.texts, isEmpty);
    expect(next.selection, blue);
  });

  test('testABlankTextGoesWhenAnotherTextIsAdded', () {
    final next = sendText(wide, [TextAction.add, TextAction.add]);

    expect(next.project.texts.map((text) => text.id).toList(), [const TextID(2)]);
    expect(next.selectedText, const TextID(2));
  });

  test('testATextWithALetterStaysWhenTheSelectionIsCleared', () {
    final next = send(wide, [
      EditorAction.text(TextAction.add),
      EditorAction.text(TextAction.setString(one, 'a')),
      EditorAction.clearSelection,
    ]);

    expect(next.project.texts.map((text) => text.string).toList(), ['a']);
    expect(next.selectedText, isNull);
  });

  test('testATextSetBackToOneSpaceGoesWhenTheSelectionIsCleared', () {
    final next = send(wide, [
      EditorAction.text(TextAction.add),
      EditorAction.text(TextAction.setString(one, 'a')),
      EditorAction.text(TextAction.setString(one, ' ')),
      EditorAction.clearSelection,
    ]);

    expect(next.project.texts, isEmpty);
  });

  test('testATextThatIsNotBlankStaysAsItWasAfterSelectAndClear', () {
    final next = send(textWide, [EditorAction.text(TextAction.select(one)), EditorAction.clearSelection]);

    expect(next.project.texts, Seed.textWide.project.texts);
    expect(next.selectedText, isNull);
  });

  test('testATextThatIsNotSelectedGoesWhenItIsGivenABlankString', () {
    final unselected = sendText(textWide, [TextAction.setString(one, ' \n')]);
    final selected = sendText(textWide, [TextAction.select(one), TextAction.setString(one, ' \n')]);

    expect(unselected.project.texts, isEmpty);
    expect(selected.project.texts.map((text) => text.string).toList(), [' \n']);
  });

  // The string

  test('testAStringIsStoredAsGivenScalarForScalar', () {
    final given = '  a\n${arabicLine()}  ';
    const head = [0x20, 0x20, 0x61, 0x0A];
    const tail = [0x20, 0x20];
    final expected = [...head, ...arabicLineScalars, ...tail];

    final next = sendText(playing(wide), [TextAction.add, TextAction.setString(one, given)]);
    final stored = (next.project.text(one)?.string ?? '').runes.toList();

    expect(stored, expected);
  });

  test('testSetStringPauses', () {
    final next = sendText(playing(textWide), [TextAction.setString(one, 'a')]);

    expect(next.project.text(one)?.string, 'a');
    expect(next.isPlaying, isFalse);
  });

  // The style

  test('testASizeIsHeldAt16FromBelow', () {
    expect(sizeAfter(16.5), 16.5);
    expect(sizeAfter(16), 16);
    expect(sizeAfter(15.5), 16);
    expect(sizeAfter(5), 16);
  });

  test('testASizeIsHeldAt400FromAbove', () {
    expect(sizeAfter(399.5), 399.5);
    expect(sizeAfter(400), 400);
    expect(sizeAfter(400.5), 400);
    expect(sizeAfter(1000), 400);
  });

  test('testALineSpacingIsHeldAt0FromBelow', () {
    expect(spacingAfter(0.25), 0.25);
    expect(spacingAfter(0), 0);
    expect(spacingAfter(-0.25), 0);
    expect(spacingAfter(-1), 0);
  });

  test('testALineSpacingIsHeldAt2FromAbove', () {
    expect(spacingAfter(1.75), 1.75);
    expect(spacingAfter(2), 2);
    expect(spacingAfter(2.25), 2);
    expect(spacingAfter(3), 2);
  });

  test('testTheRestOfAStyleIsStoredAsGivenAndSetStylePauses', () {
    const given = TextStyle(
      font: TextFont.system,
      size: 100,
      colour: RGB(r: 10, g: 132, b: 255),
      align: TextAlign.right,
      lineSpacing: 1,
      outline: true,
      shadow: true,
      box: true,
    );

    final next = sendText(playing(textWide), [TextAction.setStyle(one, given)]);

    expect(next.project.text(one)?.style, given);
    expect(next.isPlaying, isFalse);
  });

  // The centre

  test('testAMoveInsideTheCanvasIsStoredAsGivenAndPauses', () {
    final next = sendText(playing(textWide), [TextAction.move(one, 300, 200)]);

    expect(next.project.text(one)?.x, 300);
    expect(next.project.text(one)?.y, 200);
    expect(next.isPlaying, isFalse);
  });

  test('testACentreIsHeldAtTheLeftEdge', () {
    expect(centreAfter(textWide, 1, 500), [1, 500]);
    expect(centreAfter(textWide, 0, 500), [0, 500]);
    expect(centreAfter(textWide, -1, 500), [0, 500]);
  });

  test('testACentreIsHeldAtTheRightEdge', () {
    expect(centreAfter(textWide, 1919, 500), [1919, 500]);
    expect(centreAfter(textWide, 1920, 500), [1920, 500]);
    expect(centreAfter(textWide, 1921, 500), [1920, 500]);
  });

  test('testACentreIsHeldAtTheTopEdge', () {
    expect(centreAfter(textWide, 500, 1), [500, 1]);
    expect(centreAfter(textWide, 500, 0), [500, 0]);
    expect(centreAfter(textWide, 500, -1), [500, 0]);
  });

  test('testACentreIsHeldAtTheBottomEdge', () {
    expect(centreAfter(textWide, 500, 1079), [500, 1079]);
    expect(centreAfter(textWide, 500, 1080), [500, 1080]);
    expect(centreAfter(textWide, 500, 1081), [500, 1080]);
  });

  test('testTheCornersOfTheLandscapeCanvasAreInside', () {
    expect(centreAfter(textWide, 5000, -5), [1920, 0]);
    expect(centreAfter(textWide, 1920, 1080), [1920, 1080]);
    expect(centreAfter(textWide, 0, 0), [0, 0]);
  });

  test('testACentreIsHeldInsideThePortraitCanvas', () {
    final start = sendText(tall, [TextAction.add]);

    expect(centreAfter(start, -1, 3000), [0, 1920]);
    expect(centreAfter(start, 1080, 1920), [1080, 1920]);
    expect(centreAfter(start, 1081, 1921), [1080, 1920]);
  });

  // The rotation

  test('testATurnInsideTheLimitsIsStoredAsGivenAndPauses', () {
    final next = sendText(playing(textWide), [TextAction.turn(one, 90)]);

    expect(next.project.text(one)?.rotation, 90);
    expect(next.isPlaying, isFalse);
  });

  test('testATurnPast180ComesBackFromTheOtherSide', () {
    expect(angleAfter(179), 179);
    expect(angleAfter(180), 180);
    expect(angleAfter(181), -179);
    expect(angleAfter(190), -170);
    expect(angleAfter(540), 180);
    expect(angleAfter(725), 5);
    expect(angleAfter(900), 180);
  });

  test('testATurnToMinus180OrBelowComesBackFromTheOtherSide', () {
    expect(angleAfter(-179), -179);
    expect(angleAfter(-180), 180);
    expect(angleAfter(-181), 179);
    expect(angleAfter(-190), 170);
    expect(angleAfter(-725), -5);
    expect(angleAfter(-900), 180);
  });

  test('testATurnAtMost3Above0Becomes0', () {
    expect(angleAfter(2), 0);
    expect(angleAfter(3), 0);
    expect(angleAfter(3.5), 3.5);
    expect(angleAfter(362), 0);
  });

  test('testATurnAtMost3Below0Becomes0', () {
    expect(angleAfter(-2), 0);
    expect(angleAfter(-3), 0);
    expect(angleAfter(-3.5), -3.5);
  });

  // The trims

  test('testATrimOfTheStartStoresARangeRoundedTowardZeroToWholeFrames', () {
    expect(afterTrimStart(textWide, 600), range(600, 3600));
    expect(afterTrimStart(textWide, 619), range(600, 3600));
    expect(afterTrimStart(textBoxWide, -39), range(580, 920));
  });

  test('testATrimOfTheEndStoresARangeRoundedTowardZeroToWholeFrames', () {
    expect(afterTrimEnd(textWide, 600), range(0, 3600));
    expect(afterTrimEnd(textWide, 619), range(0, 3600));
    expect(afterTrimEnd(textBoxWide, -39), range(600, 920));
  });

  test('testATrimOfTheStartLeavesAtLeastTheMinimumText', () {
    expect(afterTrimStart(textBoxWide, 820), range(1420, 80));
    expect(afterTrimStart(textBoxWide, 840), range(1440, 60));
    expect(afterTrimStart(textBoxWide, 860), range(1440, 60));
    expect(afterTrimStart(textWide, 9000), range(4140, 60));
  });

  test('testATrimOfTheEndLeavesAtLeastTheMinimumText', () {
    expect(afterTrimEnd(textBoxWide, 820), range(600, 80));
    expect(afterTrimEnd(textBoxWide, 840), range(600, 60));
    expect(afterTrimEnd(textBoxWide, 860), range(600, 60));
    expect(afterTrimEnd(textWide, 9000), range(0, 60));
  });

  test('testATrimOfTheStartIsHeldAtTheStartOfTheProject', () {
    expect(afterTrimStart(textBoxWide, -580), range(20, 1480));
    expect(afterTrimStart(textBoxWide, -600), range(0, 1500));
    expect(afterTrimStart(textBoxWide, -620), range(0, 1500));
    expect(afterTrimStart(textBoxWide, -9000), range(0, 1500));
  });

  test('testATrimOfTheEndIsHeldAtTheEndOfTheProject', () {
    expect(afterTrimEnd(textBoxWide, -2680), range(600, 3580));
    expect(afterTrimEnd(textBoxWide, -2700), range(600, 3600));
    expect(afterTrimEnd(textBoxWide, -2720), range(600, 3600));
    expect(afterTrimEnd(textBoxWide, -9000), range(600, 3600));
  });

  test('testAResultFromZeroToTheProjectLengthIsStoredAsWhole', () {
    final fromZero = sendText(textBoxWide, [TextAction.trimStart(one, const Time(ticks: -9000))]);
    final fromTwenty = sendText(textWide, [TextAction.trimStart(one, const Time(ticks: 20))]);

    expect(span(fromZero), range(0, 1500));
    expect(afterTrimEnd(fromZero, -2680), range(0, 4180));
    expect(afterTrimEnd(fromZero, -9000), TextSpan.whole);
    expect(span(fromTwenty), range(20, 4180));
    expect(afterTrimStart(fromTwenty, -20), TextSpan.whole);
  });

  test('testANegativeTrimOfAWholeTextLeavesItWhole', () {
    expect(afterTrimStart(textWide, -600), TextSpan.whole);
    expect(afterTrimEnd(textWide, -600), TextSpan.whole);
  });

  test('testATrimWorksOnTheRangeAsItIsSeen', () {
    final cut = shortened(textBoxWide, 1200);

    expect(cut.project.range(one), const TextRange(start: Time(ticks: 600), duration: Time(ticks: 600)));
    expect(afterTrimEnd(cut, 200), range(600, 400));
  });

  test('testATrimOfATextWithNoRangeChangesNothing', () {
    final past = playing(shortened(textBoxWide, 300));

    expect(past.project.range(one), isNull);
    expect(sendText(past, [TextAction.trimStart(one, const Time(ticks: 20))]), past);
    expect(sendText(past, [TextAction.trimEnd(one, const Time(ticks: 20))]), past);
  });

  test('testATrimPauses', () {
    expect(sendText(playing(textWide), [TextAction.trimStart(one, const Time(ticks: 600))]).isPlaying, isFalse);
    expect(sendText(playing(textWide), [TextAction.trimEnd(one, const Time(ticks: 600))]).isPlaying, isFalse);
  });

  test('testATrimOfTheStartOfAShortRangeMovesTheStartBackToTheMinimumText', () {
    final short = shortened(textBoxWide, 620);

    expect(short.project.range(one), const TextRange(start: Time(ticks: 600), duration: Time(ticks: 20)));
    expect(afterTrimStart(short, 20), range(560, 60));
    expect(afterTrimStart(short, 0), range(560, 60));
    expect(afterTrimStart(short, 9000), range(560, 60));
  });

  test('testATrimOfTheEndOfAShortRangeChangesNothing', () {
    final short = playing(shortened(textBoxWide, 620));

    expect(sendText(short, [TextAction.trimEnd(one, const Time(ticks: 20))]), short);
    expect(sendText(short, [TextAction.trimEnd(one, const Time(ticks: -20))]), short);
  });

  test('testATrimOfTheEndWorksOnARangeOfExactlyTheMinimumText', () {
    final least = sendText(textBoxWide, [TextAction.trimEnd(one, const Time(ticks: 840))]);

    expect(span(least), range(600, 60));
    expect(afterTrimEnd(least, -40), range(600, 100));
    expect(afterTrimEnd(least, 20), range(600, 60));
  });

  // Values that are not finite numbers

  const notFinite = [double.nan, double.infinity, double.negativeInfinity];

  test('testASizeOrALineSpacingThatIsNotAFiniteNumberChangesNothing', () {
    final start = playing(textWide);

    for (final value in notFinite) {
      final size = TextStyle.standard.copyWith(size: value);
      final spacing = TextStyle.standard.copyWith(lineSpacing: value);

      expect(sendText(start, [TextAction.setStyle(one, size)]), start, reason: 'size $value');
      expect(sendText(start, [TextAction.setStyle(one, spacing)]), start, reason: 'line spacing $value');
    }
  });

  test('testAPlaceThatIsNotAFiniteNumberChangesNothing', () {
    final start = playing(textWide);

    for (final value in notFinite) {
      expect(sendText(start, [TextAction.move(one, value, 200)]), start, reason: 'x $value');
      expect(sendText(start, [TextAction.move(one, 300, value)]), start, reason: 'y $value');
    }
  });

  test('testAnAngleThatIsNotAFiniteNumberChangesNothing', () {
    final start = playing(textWide);

    for (final value in notFinite) {
      expect(sendText(start, [TextAction.turn(one, value)]), start, reason: 'angle $value');
    }
  });

  // Pausing

  test('testAnActionOnAKnownTextPausesAlsoWhenTheValueIsTheOldOne', () {
    final start = playing(textWide);
    final string = Seed.textWide.project.texts.first.string;
    final actions = <TextAction>[
      TextAction.setString(one, string),
      TextAction.setStyle(one, TextStyle.standard),
      TextAction.move(one, 960, 540),
      TextAction.turn(one, 0),
      TextAction.trimStart(one, Time.zero),
      TextAction.trimEnd(one, Time.zero),
    ];

    for (final action in actions) {
      final next = sendText(start, [action]);

      expect(next.project, start.project, reason: '$action');
      expect(next.isPlaying, isFalse, reason: '$action');
    }
  });

  // Delete

  test('testTheDeleteOfASelectedTextPauses', () {
    final start = playing(sendText(textWide, [TextAction.select(one)]));

    expect(send(start, [EditorAction.deleteSelected]).isPlaying, isFalse);
  });

  test('testDeleteRemovesTheSelectedTextAndTouchesNoClip', () {
    final start = sendText(textWide, [TextAction.select(one)]);

    final next = send(start, [EditorAction.deleteSelected]);

    expect(next.project.texts, isEmpty);
    expect(next.selectedText, isNull);
    expect(next.project.clips, start.project.clips);
    expect(next.project.clips.map((clip) => clip.id).toList(), [blue, red]);
    expect(next.project.duration, const Time(ticks: 4200));
  });

  test('testDeleteIsEnabledForASelectedTextOfTheProject', () {
    final unknown = textWide.copyWith(selectedText: () => const TextID(99));
    final selected = sendText(textWide, [TextAction.select(one)]);

    expect(selected.selection, isNull);
    expect(selected.canDelete, isTrue);
    expect(textWide.canDelete, isFalse);
    expect(unknown.canDelete, isFalse);
  });

  // Texts and clip actions

  test('testNoClipActionChangesAText', () {
    final texts = Seed.textBoxWide.project.texts;
    var state = send(textBoxWide, [
      EditorAction.addClips([TestClip.green.info]),
    ]);
    expect(state.project.texts, texts);

    state = send(state, [EditorAction.movePlayhead(const Time(ticks: 600)), EditorAction.split]);
    expect(state.project.clips.length, 4);
    expect(state.project.texts, texts);

    state = send(state, [EditorAction.trimStart(red, const Time(ticks: 600))]);
    expect(state.project.texts, texts);

    state = send(state, [EditorAction.trimEnd(red, const Time(ticks: 600))]);
    expect(state.project.duration, const Time(ticks: 4200));
    expect(state.project.texts, texts);

    while (state.project.clips.isNotEmpty) {
      final first = state.project.clips.first;
      state = send(state, [EditorAction.select(first.id), EditorAction.deleteSelected]);
      expect(state.project.texts, texts);
    }
    expect(state.project.duration, Time.zero);
  });

  test('testAWholeTextFollowsTheProjectWhenAClipIsDeleted', () {
    final next = send(textWide, [EditorAction.select(red), EditorAction.deleteSelected]);

    expect(next.project.range(one), const TextRange(start: Time.zero, duration: Time(ticks: 1800)));
  });

  // An unknown text

  test('testEveryActionOnAnUnknownTextChangesNothing', () {
    const unknown = TextID(99);
    final start = playing(textWide);
    final actions = <TextAction>[
      TextAction.select(unknown),
      TextAction.setString(unknown, 'a'),
      TextAction.setStyle(unknown, TextStyle.standard),
      TextAction.move(unknown, 1, 2),
      TextAction.turn(unknown, 90),
      TextAction.trimStart(unknown, const Time(ticks: 600)),
      TextAction.trimEnd(unknown, const Time(ticks: 600)),
    ];

    for (final action in actions) {
      expect(sendText(start, [action]), start, reason: '$action');
    }
  });
}
