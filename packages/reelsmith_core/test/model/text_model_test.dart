import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

/// The Arabic line of the seed `text-wide`, as its 21 scalars.
const List<int> arabicLineScalars = [
  0x0627, 0x0644, 0x0633, 0x0651, 0x064E, 0x0644, 0x064E, 0x0627, 0x0645, 0x064F, 0x0020, //
  0x0639, 0x064E, 0x0644, 0x064E, 0x064A, 0x0652, 0x0643, 0x064F, 0x0645, 0x0652,
];

/// The Arabic line as a string, built from its scalars.
String arabicLine() => String.fromCharCodes(arabicLineScalars);

/// A text with the standard style in the middle of the landscape canvas.
TextItem textItem(int id, String string, TextSpan span) =>
    TextItem(id: TextID(id), string: string, span: span, x: 960, y: 540, rotation: 0, style: TextStyle.standard);

/// A portrait project of one clip of the given length.
Project projectOfOneClip(int ticks) {
  final info = MediaInfo(
    id: const MediaID('long'),
    fileName: 'long.mov',
    width: 1080,
    height: 1920,
    duration: Time(ticks: ticks),
    quarterTurns: 0,
    hasSound: false,
  );
  return const Project().copyWith(
    media: {info.id: info},
    clips: [Clip(id: const ClipID(1), media: info.id, sourceStart: Time.zero, duration: info.duration)],
    nextClipID: 2,
  );
}

void main() {
  test('testTheThreeFacesInTheirOrderWithTheirNamesAndTheirWordKeys', () {
    expect(TextFont.allCases, [TextFont.naskh, TextFont.naskhBold, TextFont.system]);
    expect(TextFont.allCases.map((font) => font.rawValue).toList(), ['naskh', 'naskh-bold', 'system']);
    expect(TextFont.naskh.words, Words('text.font.naskh'));
    expect(TextFont.naskhBold.words, Words('text.font.naskhBold'));
    expect(TextFont.system.words, Words('text.font.system'));
    expect(TextFont.allWords, ['text.font.naskh', 'text.font.naskhBold', 'text.font.system']);
  });

  test('testTheThreeSidesOfAnAlignment', () {
    expect(TextAlign.allCases, [TextAlign.left, TextAlign.centre, TextAlign.right]);
    expect(TextAlign.allCases.map((align) => align.rawValue).toList(), ['left', 'centre', 'right']);
  });

  test('testTheStandardStyle', () {
    expect(
      TextStyle.standard,
      const TextStyle(
        font: TextFont.naskh,
        size: 64,
        colour: RGB(r: 255, g: 255, b: 255),
        align: TextAlign.centre,
        lineSpacing: 0,
        outline: false,
        shadow: false,
        box: false,
      ),
    );
  });

  test('testThePaletteHoldsItsEightColoursInOrder', () {
    expect(TextStyle.palette, const [
      RGB(r: 255, g: 255, b: 255),
      RGB(r: 0, g: 0, b: 0),
      RGB(r: 255, g: 214, b: 10),
      RGB(r: 255, g: 69, b: 58),
      RGB(r: 48, g: 209, b: 88),
      RGB(r: 10, g: 132, b: 255),
      RGB(r: 255, g: 105, b: 180),
      RGB(r: 142, g: 142, b: 147),
    ]);
  });

  test('testATextOfSpacesAndLineBreaksIsBlank', () {
    expect(textItem(1, '', TextSpan.whole).isBlank, isTrue);
    expect(textItem(1, ' ', TextSpan.whole).isBlank, isTrue);
    expect(textItem(1, '\n', TextSpan.whole).isBlank, isTrue);
    expect(textItem(1, '  \n  ', TextSpan.whole).isBlank, isTrue);
    expect(textItem(1, 'a', TextSpan.whole).isBlank, isFalse);
    expect(textItem(1, arabicLine(), TextSpan.whole).isBlank, isFalse);
  });

  test('testAStringIsStoredScalarForScalar', () {
    final item = textItem(1, 'a\n${arabicLine()}', TextSpan.whole);

    expect(item.string.runes.toList(), [0x61, 0x0A, ...arabicLineScalars]);
  });

  test('testANewProjectHasNoTextAndCountsItsTextIdsFrom1', () {
    expect(const Project().texts, <TextItem>[]);
    expect(const Project().nextTextID, 1);
    expect(const Project(canvas: Canvas.landscape).texts, <TextItem>[]);
    expect(const Project(canvas: Canvas.landscape).nextTextID, 1);
  });

  test('testATextAndItsPositionAreFoundByItsId', () {
    final first = textItem(4, 'a', TextSpan.whole);
    final second = textItem(7, 'b', TextSpan.whole);
    final project = const Project().copyWith(texts: [first, second]);

    expect(project.text(const TextID(4)), first);
    expect(project.text(const TextID(7)), second);
    expect(project.text(const TextID(1)), isNull);
    expect(project.positionOfText(const TextID(4)), 1);
    expect(project.positionOfText(const TextID(7)), 2);
    expect(project.positionOfText(const TextID(1)), isNull);
  });

  test('testAWholeTextRunsFromZeroToTheProjectLength', () {
    expect(
      Seed.textWide.project.range(const TextID(1)),
      const TextRange(start: Time.zero, duration: Time(ticks: 4200)),
    );
  });

  test('testARangeIsCutAtTheProjectEnd', () {
    final project = projectOfOneClip(1200).copyWith(
      texts: [
        textItem(1, 'a', const TextSpan.range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900)))),
        textItem(2, 'b', const TextSpan.range(TextRange(start: Time(ticks: 200), duration: Time(ticks: 400)))),
      ],
    );

    expect(project.range(const TextID(1)), const TextRange(start: Time(ticks: 600), duration: Time(ticks: 600)));
    expect(project.range(const TextID(2)), const TextRange(start: Time(ticks: 200), duration: Time(ticks: 400)));
  });

  test('testThereIsNoRangeForAnUnknownIdAnEmptyProjectOrAStartAtTheEnd', () {
    final empty = const Project().copyWith(
      texts: [
        textItem(1, 'a', TextSpan.whole),
        textItem(2, 'b', const TextSpan.range(TextRange(start: Time.zero, duration: Time(ticks: 600)))),
      ],
    );
    final short = projectOfOneClip(1200).copyWith(
      texts: [
        textItem(1, 'a', const TextSpan.range(TextRange(start: Time(ticks: 1200), duration: Time(ticks: 600)))),
        textItem(2, 'b', const TextSpan.range(TextRange(start: Time(ticks: 1800), duration: Time(ticks: 600)))),
      ],
    );

    expect(short.range(const TextID(9)), isNull);
    expect(empty.range(const TextID(1)), isNull);
    expect(empty.range(const TextID(2)), isNull);
    expect(short.range(const TextID(1)), isNull);
    expect(short.range(const TextID(2)), isNull);
  });

  test('testTheFootageIsTheSameWhenOnlyTheTextsDiffer', () {
    final plain = Seed.twoClipsWide.project;
    final withText = plain.copyWith(texts: [textItem(1, 'a', TextSpan.whole)], nextTextID: 2);

    expect(plain.sameFootage(withText), isTrue);
    expect(withText.sameFootage(plain), isTrue);
  });

  test('testTheFootageDiffersWithTheCanvasAClipOrAMediaFact', () {
    final plain = Seed.twoClipsWide.project;
    final otherCanvas = plain.copyWith(canvas: Canvas.portrait);
    final otherClip = plain.copyWith(
      clips: [plain.clips[0], plain.clips[1].copyWith(duration: const Time(ticks: 1200))],
    );
    const red = MediaID('red');
    final otherMedia = plain.copyWith(media: {...plain.media, red: plain.media[red]!.copyWith(hasSound: false)});

    expect(plain.sameFootage(otherCanvas), isFalse);
    expect(plain.sameFootage(otherClip), isFalse);
    expect(plain.sameFootage(otherMedia), isFalse);
  });
}
