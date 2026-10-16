import 'dart:io';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the shared draft fixtures of `Tests/Fixtures/Drafts/`, from both sides. Each file of `swift/` was written
// by Swift's `encodeDraft` and decodes here to its expected value. Each file of `dart/` is the Dart encoding of the
// file of the same name in `swift/`: with REELSMITH_WRITE_FIXTURES set this test first writes each file of `dart/`
// that is missing, never one that is there, and in both modes it holds that every file equals that encoding.
// `DraftFixtureTests.swift` decodes both folders. A fixture never changes: a new field brings a new fixture.
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

  /// text-wide with a music whose members all differ, its text outlined and not shadowed, then the text moved: a
  /// history of one step, its run shaping.
  Draft musicTextShaping() {
    final project = Seed.textWide.project;
    final text = project.texts[0];
    final music = Music(
      file: const MusicFile(
        id: MediaID('evening-id'),
        fileName: 'evening.m4a',
        title: 'Evening',
        duration: Time(ticks: 9000),
      ),
      start: const Time(ticks: 600),
      volume: 0.45,
      fadeIn: const Time(ticks: 300),
      fadeOut: const Time(ticks: 900),
    );
    final editing = Editing(
      EditorState(
        project.copyWith(
          texts: [text.copyWith(style: text.style.copyWith(outline: true, shadow: false))],
          music: () => music,
        ),
      ),
    ).after(const EditorAction.text(TextAction.move(TextID(1), 100, 200)));
    return Draft(
      project: editing.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: date,
      history: editing.history,
    );
  }

  /// text-wide after one drag step: a history whose run is drag.
  Draft historyDrag() {
    final editing = Editing(
      EditorState(Seed.textWide.project),
    ).afterDragStep(const EditorAction.frame(FrameAction.setBackdrop(ClipID(1), Backdrop.blurred)));
    return Draft(
      project: editing.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: date,
      history: editing.history,
    );
  }

  /// text-wide after red deleted, the text typed and one undo: one step past, one to come, no run.
  Draft historyUndone() {
    final editing = Editing(EditorState(Seed.textWide.project))
        .after(const EditorAction.select(ClipID(2)))
        .after(EditorAction.deleteSelected)
        .after(const EditorAction.text(TextAction.setString(TextID(1), 'Peace')))
        .undone();
    return Draft(
      project: editing.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: date,
      history: editing.history,
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
    'music-text-shaping.json': musicTextShaping(),
    'history-drag.json': historyDrag(),
    'history-undone.json': historyUndone(),
  };

  List<String> names(String side) =>
      Directory('$folder/$side').listSync().map((file) => file.uri.pathSegments.last).toList()..sort();

  test('testEachFixtureOfSwiftDecodesToItsExpectedValue', () {
    for (final seed in Seed.allCases) {
      expect(expected['seed-${seed.rawValue}.json']!.history!.past.length, 2, reason: seed.rawValue);
    }
    expect(expected['music-text-shaping.json']!.history!.run, const EditRun.shaping(TextID(1)));
    expect(expected['history-drag.json']!.history!.run, EditRun.drag);
    expect(expected['history-undone.json']!.history!.run, isNull);
    expect(expected['history-undone.json']!.history!.future, isNotEmpty);

    expect(names('swift'), expected.keys.toList()..sort());
    for (final MapEntry(key: name, value: draft) in expected.entries) {
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
      if (writes && !file.existsSync()) {
        file.writeAsBytesSync(encoding);
      }

      expect(file.readAsBytesSync(), encoding, reason: name);
      expect(decodeDraft(file.readAsBytesSync()), draft, reason: name);
    }
    expect(names('dart'), expected.keys.toList()..sort());
  });
}
