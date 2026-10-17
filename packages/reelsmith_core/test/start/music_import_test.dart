import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  final refusedProtected = MusicImportEvent.refused(true);
  final refusedUnreadable = MusicImportEvent.refused(false);

  test('testPickedMakesIdleIntoCopying', () {
    expect(MusicImport.idle.after(MusicImportEvent.picked), MusicImport.copying);
  });

  test('testImportedMakesCopyingIntoIdle', () {
    expect(MusicImport.copying.after(MusicImportEvent.imported), MusicImport.idle);
  });

  test('testRefusedMakesCopyingIntoFailedWithTheSameFlag', () {
    expect(MusicImport.copying.after(refusedProtected), MusicImport.failed(true));
    expect(MusicImport.copying.after(refusedUnreadable), MusicImport.failed(false));
  });

  test('testFailureConfirmedMakesFailedIntoIdle', () {
    expect(MusicImport.failed(true).after(MusicImportEvent.failureConfirmed), MusicImport.idle);
    expect(MusicImport.failed(false).after(MusicImportEvent.failureConfirmed), MusicImport.idle);
  });

  test('testPickedMakesFailedIntoCopying', () {
    expect(MusicImport.failed(true).after(MusicImportEvent.picked), MusicImport.copying);
    expect(MusicImport.failed(false).after(MusicImportEvent.picked), MusicImport.copying);
  });

  test('testEveryOtherPairLeavesTheCaseUnchanged', () {
    final pairs = <(MusicImport, MusicImportEvent)>[
      (MusicImport.idle, MusicImportEvent.imported),
      (MusicImport.idle, refusedProtected),
      (MusicImport.idle, refusedUnreadable),
      (MusicImport.idle, MusicImportEvent.failureConfirmed),
      (MusicImport.copying, MusicImportEvent.failureConfirmed),
      (MusicImport.copying, MusicImportEvent.picked),
      (MusicImport.failed(true), MusicImportEvent.imported),
      (MusicImport.failed(true), refusedUnreadable),
      (MusicImport.failed(true), refusedProtected),
      (MusicImport.failed(false), MusicImportEvent.imported),
      (MusicImport.failed(false), refusedProtected),
      (MusicImport.failed(false), refusedUnreadable),
    ];
    for (final (state, event) in pairs) {
      expect(state.after(event), state);
    }
  });

  test('testANewPickIsTheWayOutOfARefusal', () {
    final next = MusicImport.idle
        .after(MusicImportEvent.picked)
        .after(refusedProtected)
        .after(MusicImportEvent.picked);

    expect(next, MusicImport.copying);
    expect(next.words, Words('music.copying'));
  });

  test('testEachCaseGivesItsKeyWithNoArgument', () {
    expect(MusicImport.idle.words, isNull);
    expect(MusicImport.copying.words, Words('music.copying', []));
    expect(MusicImport.failed(false).words, Words('music.notReadable', []));
    expect(MusicImport.failed(true).words, Words('music.protected', []));
  });

  test('testAllWordsListsTheThreeKeysInOrder', () {
    expect(MusicImport.allWords, ['music.copying', 'music.notReadable', 'music.protected']);
  });
}
