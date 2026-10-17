import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/engine/video_engine.dart';

import 'support/fake_video_engine.dart';

void main() {
  test('the fake answers every call through VideoEngine', () async {
    final fake = FakeVideoEngine()
      ..pickAnswer = 2
      ..copyPickedAnswer = ['{"a":1}', '{"b":2}']
      ..pickAudioAnswer = true
      ..createPreviewAnswer = 7
      ..exportAnswer = ExportedVideo(file: '/x.mp4', facts: '1080x1920 30')
      ..saveToPhotosAnswer = SaveOutcome.notAllowed
      ..blockFramesAnswer = {0: Uint8List.fromList([1, 2])}
      ..faceNamesAnswer = 'Amiri-Regular Amiri-Bold'
      ..confirmAnswer = true;
    final VideoEngine engine = fake;

    expect(await engine.launch(), fake.launchAnswer);
    expect(await engine.writeSeedMedia('two-clips'), '/fake/Seeds');
    expect(await engine.readMediaInfo('id', 'id.mov', '/m'), '{}');
    expect(await engine.pick(true, 0), 2);
    expect(await engine.copyPicked('/m'), ['{"a":1}', '{"b":2}']);
    expect(await engine.pickAudio(), isTrue);
    expect(await engine.importMusic('/m'), '{}');
    expect(await engine.musicFromVideo('/m'), '{}');
    expect(await engine.createPreview(), 7);
    await engine.show(7, '{}', '/m', null, false);
    await engine.disposePreview(7);
    final exported = await engine.export('{}', '{}', '/m', false);
    expect(exported.file, '/x.mp4');
    expect(exported.facts, '1080x1920 30');
    expect(await engine.saveToPhotos('/x.mp4'), SaveOutcome.notAllowed);
    await engine.writeCover('{}', '/m', '/m/cover.png');
    expect(await engine.blockFrames('{}', '/m'), {0: Uint8List.fromList([1, 2])});
    await engine.keepAwake(true);
    expect(await engine.faceNames(), 'Amiri-Regular Amiri-Bold');
    expect(await engine.confirm('q', 'yes', 'no'), isTrue);

    expect(fake.calls, [
      'launch',
      'writeSeedMedia',
      'readMediaInfo',
      'pick',
      'copyPicked',
      'pickAudio',
      'importMusic',
      'musicFromVideo',
      'createPreview',
      'show',
      'disposePreview',
      'export',
      'saveToPhotos',
      'writeCover',
      'blockFrames',
      'keepAwake',
      'faceNames',
      'confirm',
    ]);
  });

  test('the fake gives every event through VideoEngine', () async {
    final fake = FakeVideoEngine();
    final VideoEngine engine = fake;
    final playhead = engine.playhead.first;
    final playedToEnd = engine.playedToEnd.first;
    final buildCount = engine.buildCount.first;
    final exportProgress = engine.exportProgress.first;

    fake.sendPlayhead(600);
    fake.sendPlayedToEnd();
    fake.sendBuildCount(3);
    fake.sendExportProgress(0.5);

    expect(await playhead, 600);
    await playedToEnd;
    expect(await buildCount, 3);
    expect(await exportProgress, 0.5);
  });
}
