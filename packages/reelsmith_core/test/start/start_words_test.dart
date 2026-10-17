import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Stays in Swift, since every check of it reads the word files: testEveryKeyOfTheStartScreenIsInAllThreeWordFiles.
// The check of the English file below stays in Swift too. In Dart the keys of the state and of the canvas are held
// to the keys of the start screen that the Swift test holds in all three word files.
void main() {
  const startScreen = [
    'start.title',
    'start.newProject',
    'start.landscape',
    'start.portrait',
    'start.copying',
    'start.noneReadable',
    'start.ok',
  ];

  test('testEveryKeyOfTheStartStateAndOfTheCanvasIsInTheEnglishFile', () {
    for (final key in [...StartState.allWords, ...Canvas.allWords]) {
      expect(startScreen.contains(key), isTrue, reason: 'the key $key is missing');
    }
  });
}
