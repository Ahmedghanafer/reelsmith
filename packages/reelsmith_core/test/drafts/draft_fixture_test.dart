import 'dart:io';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the shared draft fixtures of `Tests/Fixtures/Drafts/`, from both sides. Each file of `swift/` was written
// by Swift's `encodeDraft` and decodes here to its expected value. Each file of `dart/` is the Dart encoding of the
// file of the same name in `swift/`: with REELSMITH_WRITE_FIXTURES set this test writes it, otherwise it holds that
// the committed file equals that encoding. `DraftFixtureTests.swift` decodes both folders. A fixture never changes:
// a new field brings a new fixture.
void main() {
  const folder = '../../Tests/Fixtures/Drafts';
  final writes = Platform.environment.containsKey('REELSMITH_WRITE_FIXTURES');

  /// 2026-10-14 21:05:09 in UTC.
  final date = DateTime.fromMillisecondsSinceEpoch(1792011909 * 1000, isUtc: true);

  /// The seed after a clip added and a text typed: an undo history of two steps, its run typing.
  Draft twoSteps(Seed seed) {
    final text = TextID(seed.project.nextTextID);
    final editing = Editing(EditorState(seed.project))
        .after(EditorAction.addClips([TestClip.green.info]))
        .after(const EditorAction.text(TextAction.add))
        .after(EditorAction.text(TextAction.setString(text, 'Peace')));
    return Draft(
      project: editing.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: date,
      history: editing.history,
    );
  }

  /// photo-wide with blue framed, a text with every member set and 4K at 60.
  Draft photoFramingText() {
    final project = Seed.photoWide.project;
    final clips = List.of(project.clips);
    clips[0] = clips[0].copyWith(
      framing: const Framing(fit: Fit.fill, backdrop: Backdrop.blurred, zoom: 1.5, x: 0.125, y: -0.0625),
    );
    const text = TextItem(
      id: TextID(1),
      string: 'Peace\nسلام',
      span: TextSpan.range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 1200))),
      x: 3.857142857142857,
      y: 540.5,
      rotation: -45.25,
      style: TextStyle(
        font: TextFont.naskhBold,
        size: 64.1,
        colour: RGB(r: 255, g: 214, b: 10),
        align: TextAlign.right,
        lineSpacing: 0.25,
        outline: true,
        shadow: true,
        box: true,
      ),
    );
    return Draft(
      project: project.copyWith(clips: clips, texts: [text], nextTextID: 2),
      exportSettings: const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty),
      changed: date,
    );
  }

  /// The expected draft of every fixture, by its file name.
  final expected = <String, Draft>{
    'version-one.json': Draft(
      project: Seed.musicWide.project,
      exportSettings: const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty),
      changed: date,
    ),
    for (final seed in Seed.allCases) 'seed-${seed.rawValue}.json': twoSteps(seed),
    'photo-framing-text-4k.json': photoFramingText(),
  };

  List<String> names(String side) =>
      Directory('$folder/$side').listSync().map((file) => file.uri.pathSegments.last).toList()..sort();

  test('testEachFixtureOfSwiftDecodesToItsExpectedValue', () {
    expect(names('swift'), expected.keys.toList()..sort());
    for (final MapEntry(key: name, value: draft) in expected.entries) {
      expect(draft.history == null || draft.history!.past.length == 2, isTrue, reason: name);
      expect(decodeDraft(File('$folder/swift/$name').readAsBytesSync()), draft, reason: name);
    }
  });

  test('testEachFileOfDartIsTheDartEncodingOfItsFixtureOfSwift', () {
    if (writes) {
      Directory('$folder/dart').createSync(recursive: true);
    }
    for (final MapEntry(key: name, value: draft) in expected.entries) {
      final encoding = encodeDraft(decodeDraft(File('$folder/swift/$name').readAsBytesSync()));
      final file = File('$folder/dart/$name');
      if (writes) {
        file.writeAsBytesSync(encoding);
      }

      expect(file.readAsBytesSync(), encoding, reason: name);
      expect(decodeDraft(file.readAsBytesSync()), draft, reason: name);
    }
    expect(names('dart'), expected.keys.toList()..sort());
  });
}
