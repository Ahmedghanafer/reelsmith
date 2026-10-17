import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testIdleGivesNoWordsAndNoPercent', () {
    expect(ExportState.idle.words, isNull);
    expect(ExportState.idle.percentText, isNull);
  });

  test('testExportingGivesTheKeyOfExportingAndStartsAtZeroPercent', () {
    final exporting = ExportState.idle.after(ExportStateEvent.started);

    expect(exporting.words, Words('export.exporting'));
    expect(exporting.percentText, '0%');
  });

  test('testThePercentFollowsTheProgress', () {
    final exporting = ExportState.idle.after(ExportStateEvent.started);

    expect(exporting.after(ExportStateEvent.progress(0.42)).percentText, '42%');
    expect(exporting.after(ExportStateEvent.progress(1)).percentText, '100%');
  });

  test('testThePercentNeverGoesDownWhenALowerProgressArrives', () {
    final half = ExportState.idle.after(ExportStateEvent.started).after(ExportStateEvent.progress(0.5));

    expect(half.after(ExportStateEvent.progress(0.25)).percentText, '50%');
    expect(
      half.after(ExportStateEvent.progress(0.25)).after(ExportStateEvent.progress(0.75)).percentText,
      '75%',
    );
  });

  test('testThePercentIsWrittenWithTheDigitsZeroToNineFromZeroToAHundred', () {
    final exporting = ExportState.idle.after(ExportStateEvent.started);

    expect(exporting.after(ExportStateEvent.progress(-1)).percentText, '0%');
    expect(exporting.after(ExportStateEvent.progress(7)).percentText, '100%');
    for (var step = 0; step <= 20; step++) {
      final text = exporting.after(ExportStateEvent.progress(step / 20)).percentText ?? '';
      final digits = text.isEmpty ? '' : text.substring(0, text.length - 1);
      expect(text.endsWith('%'), isTrue, reason: text);
      expect(digits.isNotEmpty, isTrue, reason: text);
      expect(digits.split('').every('0123456789'.contains), isTrue, reason: text);
    }
  });

  test('testAProgressValueThatIsNotANumberChangesNothing', () {
    final half = ExportState.idle.after(ExportStateEvent.started).after(ExportStateEvent.progress(0.5));

    expect(half.after(ExportStateEvent.progress(double.nan)), half);
    expect(half.after(ExportStateEvent.progress(double.infinity)).percentText, '100%');
  });

  test('testSavedGivesTheKeyOfSavedAndNoPercent', () {
    final saved = ExportState.idle.after(ExportStateEvent.started).after(ExportStateEvent.saved);

    expect(saved, ExportState.saved);
    expect(saved.words, Words('export.saved'));
    expect(saved.percentText, isNull);
  });

  test('testFailedGivesTheKeyOfFailedOrOfNotAllowed', () {
    final exporting = ExportState.idle.after(ExportStateEvent.started);
    final failed = exporting.after(ExportStateEvent.failed(false));
    final refused = exporting.after(ExportStateEvent.failed(true));

    expect(failed, ExportState.failed(false));
    expect(failed.words, Words('export.failed'));
    expect(failed.percentText, isNull);
    expect(refused, ExportState.failed(true));
    expect(refused.words, Words('export.notAllowed'));
  });

  test('testAllWordsListsExactlyTheFourKeys', () {
    expect(ExportState.allWords, ['export.exporting', 'export.saved', 'export.failed', 'export.notAllowed']);
  });

  test('testClosingTheSavedOrTheFailedCaseGivesIdle', () {
    expect(ExportState.saved.after(ExportStateEvent.closed), ExportState.idle);
    expect(ExportState.failed(false).after(ExportStateEvent.closed), ExportState.idle);
    expect(ExportState.failed(true).after(ExportStateEvent.closed), ExportState.idle);
  });

  test('testAnEventWithNoMeaningInACaseLeavesItUnchanged', () {
    final exporting = ExportState.idle.after(ExportStateEvent.started).after(ExportStateEvent.progress(0.5));
    final failed = ExportState.failed(false);

    expect(ExportState.idle.after(ExportStateEvent.progress(0.5)), ExportState.idle);
    expect(ExportState.idle.after(ExportStateEvent.saved), ExportState.idle);
    expect(ExportState.idle.after(ExportStateEvent.failed(false)), ExportState.idle);
    expect(ExportState.idle.after(ExportStateEvent.closed), ExportState.idle);
    expect(exporting.after(ExportStateEvent.started), exporting);
    expect(exporting.after(ExportStateEvent.closed), exporting);
    // A progress value that arrives after the end changes nothing.
    expect(ExportState.saved.after(ExportStateEvent.progress(1)), ExportState.saved);
    expect(ExportState.saved.after(ExportStateEvent.started), ExportState.saved);
    expect(ExportState.saved.after(ExportStateEvent.failed(false)), ExportState.saved);
    expect(failed.after(ExportStateEvent.progress(1)), failed);
    expect(failed.after(ExportStateEvent.started), failed);
    expect(failed.after(ExportStateEvent.saved), failed);
  });

  test('testTheExportCanStartExactlyWhenTheEditorCanExportAndTheStateIsIdle', () {
    final filled = EditorState(Seed.twoClips.project);
    final empty = EditorState(Seed.empty.project);
    final exporting = ExportState.idle.after(ExportStateEvent.started);

    expect(filled.canExport, isTrue);
    expect(empty.canExport, isFalse);
    expect(ExportState.idle.canStart(filled), isTrue);
    expect(ExportState.idle.canStart(empty), isFalse);
    expect(exporting.canStart(filled), isFalse);
    expect(ExportState.saved.canStart(filled), isFalse);
    expect(ExportState.failed(false).canStart(filled), isFalse);
    expect(ExportState.failed(true).canStart(filled), isFalse);
  });
}
