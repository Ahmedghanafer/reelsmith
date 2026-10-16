import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Stays in Swift, since every check of it reads the word files: testEveryKeyOfTheExportIsInAllThreeWordFiles.
// The check of the English file below stays in Swift too. In Dart the keys of the state are held to the keys of
// the export that the Swift test holds in all three word files.
void main() {
  const export = [
    'export.button',
    'export.exporting',
    'export.saved',
    'export.done',
    'export.failed',
    'export.notAllowed',
    'export.close',
  ];

  test('testEveryKeyOfTheExportStateIsInTheEnglishFile', () {
    for (final key in ExportState.allWords) {
      expect(export.contains(key), isTrue, reason: 'the key $key is missing');
    }
  });
}
