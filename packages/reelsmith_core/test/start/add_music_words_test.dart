import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Stay in Swift, since every check of them reads the word files: testTheGroupAddMusicHoldsItsSevenKeysInAllThreeWordFiles
// and testTheEnglishTextsOfTheGroupAddMusic. The check of the English file below stays in Swift too. In Dart the keys
// of the state are held to the seven keys that the Swift test holds in the group add-music of all three word files.
void main() {
  const addMusic = [
    'music.add',
    'music.replace',
    'music.remove',
    'music.copying',
    'music.notReadable',
    'music.protected',
    'music.ok',
  ];

  test('testEveryKeyOfTheImportStateIsInTheEnglishFile', () {
    for (final key in MusicImport.allWords) {
      expect(addMusic.contains(key), isTrue, reason: 'the key $key is missing');
    }
  });
}
