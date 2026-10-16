import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/text_model_test.dart' show textItem;

/// The name of a text action. The switch is exhaustive over the sealed class, so a ninth case does not compile.
String _caseName(TextAction action) => switch (action) {
  TextActionAdd() => 'add',
  TextActionSelect() => 'select',
  TextActionSetString() => 'setString',
  TextActionSetStyle() => 'setStyle',
  TextActionMove() => 'move',
  TextActionTurn() => 'turn',
  TextActionTrimStart() => 'trimStart',
  TextActionTrimEnd() => 'trimEnd',
};

void main() {
  EditorState selected(Project project) => EditorState(project).copyWith(selectedText: () => const TextID(1));

  test('testTheEightTextActionsWithTheirLabels', () {
    const id = TextID(1);
    final actions = <TextAction>[
      TextAction.add,
      TextAction.select(id),
      TextAction.setString(id, 'a'),
      TextAction.setStyle(id, TextStyle.standard),
      TextAction.move(id, 1, 2),
      TextAction.turn(id, 3),
      TextAction.trimStart(id, const Time(ticks: 20)),
      TextAction.trimEnd(id, const Time(ticks: 20)),
    ];

    expect(actions.map(_caseName).toList(), [
      'add',
      'select',
      'setString',
      'setStyle',
      'move',
      'turn',
      'trimStart',
      'trimEnd',
    ]);
    expect(EditorAction.text(TextAction.add), EditorAction.text(TextAction.add));
    expect(EditorAction.text(TextAction.add), isNot(EditorAction.text(TextAction.select(id))));
  });

  test('testANewStateHasNoSelectedText', () {
    expect(EditorState(Seed.textWide.project).selectedText, isNull);
  });

  test('testATextCanBeAddedWhenTheProjectHasAClip', () {
    expect(EditorState(Seed.empty.project).canAddText, isFalse);
    expect(EditorState(Seed.twoClips.project).canAddText, isTrue);
  });

  test('testSelectingAClipClearsTheSelectedText', () {
    final next = reduce(selected(Seed.textWide.project), EditorAction.select(const ClipID(1)));

    expect(next.selectedText, isNull);
    expect(next.selection, const ClipID(1));
  });

  test('testClearSelectionClearsBothSelections', () {
    final clipSelected = EditorState(Seed.textWide.project).copyWith(selection: () => const ClipID(1));

    final afterText = reduce(selected(Seed.textWide.project), EditorAction.clearSelection);
    final afterClip = reduce(clipSelected, EditorAction.clearSelection);

    expect(afterText.selectedText, isNull);
    expect(afterText.selection, isNull);
    expect(afterClip.selectedText, isNull);
    expect(afterClip.selection, isNull);
  });

  test('testTextInfoIsNoneWithNoSelectedText', () {
    expect(EditorState(Seed.textWide.project).textInfo, 'none');
  });

  test('testTextInfoOfTheTwoTextSeeds', () {
    expect(selected(Seed.textWide.project).textInfo, '1 naskh 64 255,255,255 centre 960,540 0 ... 0+4200 0');
    expect(selected(Seed.textBoxWide.project).textInfo, '1 naskh 96 255,214,10 centre 960,540 0 ..b 600+900 0');
  });

  test('testTextInfoReadsHiddenForATextWithNoRange', () {
    final seed = Seed.textBoxWide.project;
    final project = seed.copyWith(
      texts: [
        seed.texts[0].copyWith(
          span: const TextSpan.range(TextRange(start: Time(ticks: 4200), duration: Time(ticks: 600))),
        ),
        ...seed.texts.skip(1),
      ],
    );
    final info = selected(project).textInfo;

    expect(info, '1 naskh 96 255,214,10 centre 960,540 0 ..b hidden 0');
    expect(info.split(' ')[8], 'hidden');
  });

  test('testTextInfoRoundsToWholeNumbersAndReadsEveryField', () {
    final project = Seed.twoClips.project.copyWith(
      texts: [
        textItem(1, 'a', TextSpan.whole),
        const TextItem(
          id: TextID(2),
          string: 'b',
          span: TextSpan.range(TextRange(start: Time(ticks: 20), duration: Time(ticks: 60))),
          x: 100.4,
          y: 200.6,
          rotation: -29.6,
          style: TextStyle(
            font: TextFont.naskhBold,
            size: 63.6,
            colour: RGB(r: 1, g: 2, b: 3),
            align: TextAlign.right,
            lineSpacing: 0.5,
            outline: true,
            shadow: true,
            box: false,
          ),
        ),
      ],
    );
    final state = EditorState(project).copyWith(selectedText: () => const TextID(2));
    final info = state.textInfo;

    expect(info, '2 naskh-bold 64 1,2,3 right 100,201 -30 os. 20+60 50');
    expect(info.split(' ')[9], '50');
  });
}
