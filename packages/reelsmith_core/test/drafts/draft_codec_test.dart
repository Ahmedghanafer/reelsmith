import 'dart:convert';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds what Swift's decoder reads beyond what our writers write: an integer written as a whole double, and a byte
// order mark before the JSON.
void main() {
  /// The literal of DraftVersionOneTests, with its ticks written as given.
  String versionOne(String blueTicks) =>
      '{"changed":813704709,"exportSettings":{"rate":{"sixty":{}},"size":{"uhd4K":{}}},"project":{"canvas":{"landscape":{}},"clipVolume":1,"clips":[{"duration":{"ticks":$blueTicks},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0}},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0}}],"clipsMuted":false,"media":[{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080},{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920}],"music":{"fadeIn":{"ticks":0},"fadeOut":{"ticks":0},"file":{"duration":{"ticks":6000},"fileName":"long-tone.mov","id":{"raw":"long-tone"},"title":"long-tone"},"start":{"ticks":0},"volume":1},"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}';

  final expected = Draft(
    project: Seed.musicWide.project,
    exportSettings: const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty),
    changed: DateTime.fromMillisecondsSinceEpoch(1792011909 * 1000, isUtc: true),
  );

  test('testAnIntegerWrittenAsAWholeNumberOfAnyFormReadsAndAFractionIsUnreadable', () {
    for (final ticks in ['1800', '1800.0', '1.8e3', '18e2']) {
      expect(decodeDraft(utf8.encode(versionOne(ticks))), expected, reason: ticks);
    }
    for (final ticks in ['1800.5', '1.8005e3']) {
      expect(() => decodeDraft(utf8.encode(versionOne(ticks))), throwsA(DraftError.unreadable), reason: ticks);
    }
  });

  test('testAByteOrderMarkBeforeTheJsonIsPassedOver', () {
    expect(decodeDraft([0xEF, 0xBB, 0xBF, ...utf8.encode(versionOne('1800'))]), expected);
  });
}
