import 'dart:convert';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the stored form of a project: `Draft`, its coding, the files a project names, the summary and its lines.
void main() {
  /// 2026-10-14 21:05:09 in UTC.
  final date = DateTime.fromMillisecondsSinceEpoch(1792011909 * 1000, isUtc: true);

  Draft roundTrip(Draft draft) => decodeDraft(encodeDraft(draft));

  test('testADraftOfEverySeedRoundTripsAtVersionOne', () {
    expect(Seed.allCases.length, 8);
    for (final seed in Seed.allCases) {
      final draft = Draft(project: seed.project, exportSettings: ExportSettings.startChoice, changed: date);

      expect(draft.version, 1, reason: seed.rawValue);
      expect(roundTrip(draft), draft, reason: seed.rawValue);
    }
    expect(Draft.currentVersion, 1);
  });

  test('testTheArabicLineAndTheLineBreakOfTextWideComeBack', () {
    final draft = Draft(project: Seed.textWide.project, exportSettings: ExportSettings.startChoice, changed: date);
    final string = roundTrip(draft).project.texts.first.string;

    expect(string, Seed.textWide.project.texts[0].string);
    expect(string.split('\n').length, 3);
    expect(string.runes.toList(), Seed.textWide.project.texts[0].string.runes.toList());
  });

  test('testNumbersOfATextComeBackExactly', () {
    final text = Seed.textWide.project.texts[0];
    final project = Seed.textWide.project.copyWith(
      texts: [
        text.copyWith(x: 3.857142857142857, style: text.style.copyWith(size: 64.1)),
      ],
    );
    final back = roundTrip(Draft(project: project, exportSettings: ExportSettings.startChoice, changed: date));

    expect(back.project, project);
    expect(back.project.texts[0].x, 3.857142857142857);
    expect(back.project.texts[0].style.size, 64.1);
  });

  test('testTheSettingsAndTheDateComeBack', () {
    const settings = ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty);
    final back = roundTrip(Draft(project: Seed.twoClipsWide.project, exportSettings: settings, changed: date));

    expect(back.exportSettings, settings);
    expect(back.changed, date);
  });

  test('testBytesThatAreNotADraftAreUnreadable', () {
    final wide = Draft(
      project: Seed.twoClipsWide.project,
      exportSettings: ExportSettings.startChoice,
      changed: date,
    ).copyWith(version: 2);
    final inputs = [utf8.encode('not json'), utf8.encode('{"a":1}'), encodeDraft(wide)];

    for (final data in inputs) {
      expect(() => decodeDraft(data), throwsA(DraftError.unreadable));
    }
  });

  test('testFileNamesAreTheFilesTheClipsAndTheMusicUse', () {
    expect(Seed.twoClipsWide.project.fileNames, ['blue.mov', 'red.mov']);
    expect(Seed.musicWide.project.fileNames, ['blue.mov', 'long-tone.mov', 'red.mov']);
    expect(Seed.empty.project.fileNames, <String>[]);

    var state = EditorState(Seed.musicWide.project);
    state = reduce(state, const EditorAction.select(ClipID(2)));
    state = reduce(state, EditorAction.deleteSelected);

    expect(state.project.media[const MediaID('red')], isNotNull);
    expect(state.project.fileNames, ['blue.mov', 'long-tone.mov']);
  });

  test('testKeepingFilesTakesOutWhatIsMissing', () {
    final project = Seed.musicWide.project;
    final blue = project.clips[0];
    final blueInfo = TestClip.blue.info;

    final noRed = project.keepingFiles({'blue.mov', 'long-tone.mov'});
    expect(noRed.clips, [blue]);
    expect(noRed.media, {blueInfo.id: blueInfo});
    expect(noRed.music, project.music);

    final noTone = project.keepingFiles({'blue.mov', 'red.mov'});
    expect(noTone.clips, project.clips);
    expect(noTone.media, project.media);
    expect(noTone.music, isNull);

    final none = project.keepingFiles({});
    expect(none.clips, <Clip>[]);
    expect(none.media, <MediaID, MediaInfo>{});
    expect(none.music, isNull);

    for (final kept in [noRed, noTone, none]) {
      expect(kept.canvas, project.canvas);
      expect(kept.clipVolume, project.clipVolume);
      expect(kept.clipsMuted, project.clipsMuted);
      expect(kept.nextClipID, project.nextClipID);
    }

    final text = Seed.textWide.project;
    for (final present in [
      {'blue.mov', 'red.mov'},
      {'blue.mov'},
      <String>{},
    ]) {
      final kept = text.keepingFiles(present);
      expect(kept.texts, text.texts);
      expect(kept.nextTextID, text.nextTextID);
      expect(kept.canvas, text.canvas);
      expect(kept.clipVolume, text.clipVolume);
      expect(kept.clipsMuted, text.clipsMuted);
      expect(kept.nextClipID, text.nextClipID);
    }
  });

  test('testAHistoryOfThreeStepsReadBackUndoesTheSameThree', () {
    final state = EditorState(Seed.textWide.project).copyWith(selectedText: () => const TextID(1));
    var editing = Editing(state);
    final style = Seed.textWide.project.texts[0].style.copyWith(outline: true);
    editing = editing.after(EditorAction.text(TextAction.setStyle(const TextID(1), style)));
    editing = editing.after(EditorAction.select(const ClipID(2)));
    editing = editing.after(EditorAction.deleteSelected);
    editing = editing.after(const EditorAction.text(TextAction.setString(TextID(1), 'Peace')));
    expect(editing.history.past.length, 3);
    expect(editing.history.run, const EditRun.typing(TextID(1)));

    final undone = <Project>[];
    var stepping = editing;
    while (stepping.canUndo) {
      stepping = stepping.undone();
      undone.add(stepping.state.project);
    }
    expect(undone.length, 3);

    final draft = Draft(
      project: editing.state.project,
      exportSettings: ExportSettings.startChoice,
      changed: date,
      history: editing.history,
    );
    final back = roundTrip(draft);
    expect(back, draft);

    final history = back.history;
    expect(history, isNotNull);
    var opened = Editing.withHistory(state: EditorState(back.project), history: history!);
    expect(opened.history.run, isNull);
    expect(opened.unsaved, isFalse);
    final undoneAfterOpen = <Project>[];
    while (opened.canUndo) {
      opened = opened.undone();
      undoneAfterOpen.add(opened.state.project);
    }

    expect(undoneAfterOpen, undone);
    expect(
      roundTrip(Draft(project: Seed.textWide.project, exportSettings: ExportSettings.startChoice, changed: date))
          .history,
      isNull,
    );
  });

  test('testTheSummaryOfADraft', () {
    const settings = ExportSettings(size: ExportSize.hd720, rate: ExportRate.sixty);
    final draft = Draft(project: Seed.textWide.project, exportSettings: settings, changed: date);
    final summary = DraftSummary(id: const DraftID('A'), draft: draft, hasCover: true);

    expect(summary.id, const DraftID('A'));
    expect(summary.duration, const Time(ticks: 4200));
    expect(summary.clipCount, 2);
    expect(summary.textCount, 1);
    expect(summary.exportSettings, settings);
    expect(summary.changed, date);
    expect(summary.hasCover, isTrue);
    expect(summary.isReadable, isTrue);
  });

  test('testTheSummaryOfAnUnreadableDraft', () {
    final summary = DraftSummary.unreadable(const DraftID('B'), hasCover: false);

    expect(summary.id, const DraftID('B'));
    expect(summary.changed, isNull);
    expect(summary.duration, Time.zero);
    expect(summary.clipCount, 0);
    expect(summary.textCount, 0);
    expect(summary.exportSettings, ExportSettings.standard);
    expect(summary.hasCover, isFalse);
    expect(summary.isReadable, isFalse);
  });

  test('testDateText', () {
    expect(dateText(date, inUtc: true), '2026-10-14 21:05');
    expect(
      dateText(DateTime.fromMillisecondsSinceEpoch(1767323040 * 1000, isUtc: true), inUtc: true),
      '2026-01-02 03:04',
    );

    final digits = '0123456789 -:'.split('').toSet();
    expect(dateText(date, inUtc: true).split('').every(digits.contains), isTrue);
  });

  test('testDraftsInfo', () {
    final blue = TestClip.blue.info;
    final short = const Project(canvas: Canvas.landscape).copyWith(
      media: {blue.id: blue},
      clips: [Clip(id: const ClipID(1), media: blue.id, sourceStart: Time.zero, duration: blue.duration)],
      nextClipID: 2,
      texts: Seed.textWide.project.texts,
      nextTextID: 2,
    );
    final first = DraftSummary(
      id: const DraftID('A'),
      draft: Draft(
        project: short,
        exportSettings: const ExportSettings(size: ExportSize.hd720, rate: ExportRate.sixty),
        changed: date,
      ),
      hasCover: true,
    );
    final second = DraftSummary(
      id: const DraftID('B'),
      draft: Draft(project: Seed.twoClipsWide.project, exportSettings: ExportSettings.standard, changed: date),
      hasCover: false,
    );

    expect(draftsInfo([]), '0');
    expect(draftsInfo([first, second]), '2 1+1800+1+720x60+c 2+4200+0+1080x30+.');
    expect(draftsInfo([DraftSummary.unreadable(const DraftID('C'), hasCover: true)]), '1 x');
  });
}
