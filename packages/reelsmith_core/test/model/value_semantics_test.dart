import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the value semantics of Swift's model types: a list or map changed after a value was made changes no value,
// and the lists and the map a value holds cannot be changed.
void main() {
  test('aListOrMapChangedAfterTheValueWasMadeChangesNoValue', () {
    final clip = Clip(
      id: const ClipID(1),
      media: TestClip.blue.info.id,
      sourceStart: Time.zero,
      duration: TestClip.blue.duration,
    );
    final clips = [clip];
    final media = {TestClip.blue.info.id: TestClip.blue.info};
    final text = TextItem(
      id: const TextID(1),
      string: 'a',
      span: TextSpan.whole,
      x: 0,
      y: 0,
      rotation: 0,
      style: TextStyle.standard,
    );
    final texts = [text];
    final project = const Project().copyWith(clips: clips, media: media, texts: texts);
    final arguments = ['3'];
    final words = Words('clip.count', arguments);

    clips.add(clip.copyWith(id: const ClipID(2)));
    media.clear();
    texts.clear();
    arguments[0] = '4';

    expect(project.clips, [clip]);
    expect(project.media, {TestClip.blue.info.id: TestClip.blue.info});
    expect(project.texts, [text]);
    expect(words, Words('clip.count', ['3']));
    expect(() => project.clips.add(clip), throwsUnsupportedError);
    expect(() => project.media.clear(), throwsUnsupportedError);
    expect(() => project.texts.clear(), throwsUnsupportedError);
    expect(() => words.arguments[0] = '5', throwsUnsupportedError);
  });
}
