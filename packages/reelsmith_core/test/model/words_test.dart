import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testWordsHoldAKeyAndItsArguments', () {
    expect(Words('export.saved').key, 'export.saved');
    expect(Words('export.saved').arguments, <String>[]);
    expect(Words('clip.count', ['2']).arguments, ['2']);
  });

  test('testWordsAreEqualExactlyWhenKeyAndArgumentsAre', () {
    expect(Words('clip.count', ['2']), Words('clip.count', ['2']));
    expect(Words('clip.count', ['2']), isNot(Words('clip.length', ['2'])));
    expect(Words('clip.count', ['2']), isNot(Words('clip.count', ['3'])));
  });

  test('testClockTextAndTimeLabelArePlainText', () {
    final String clock = Time.zero.clockText;
    final String label = EditorState(Seed.empty.project).timeLabel;

    expect(clock, '00:00');
    expect(label, '00:00 / 00:00');
  });
}
