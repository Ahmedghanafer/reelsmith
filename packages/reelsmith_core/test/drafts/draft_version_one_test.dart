import 'dart:convert';

import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds that a draft of version 1 stays readable: the literal is the draft of `music-wide` at 4K and 60 with the
// date 2026-10-14 21:05:09 in UTC, as `encodeDraft` wrote it when the stored form was made.
void main() {
  const versionOne =
      '{"changed":813704709,"exportSettings":{"rate":{"sixty":{}},"size":{"uhd4K":{}}},"project":{"canvas":{"landscape":{}},"clipVolume":1,"clips":[{"duration":{"ticks":1800},"id":{"raw":1},"media":{"raw":"blue"},"sourceStart":{"ticks":0}},{"duration":{"ticks":2400},"id":{"raw":2},"media":{"raw":"red"},"sourceStart":{"ticks":0}}],"clipsMuted":false,"media":[{"raw":"red"},{"duration":{"ticks":2400},"fileName":"red.mov","hasSound":true,"height":1920,"id":{"raw":"red"},"quarterTurns":0,"width":1080},{"raw":"blue"},{"duration":{"ticks":1800},"fileName":"blue.mov","hasSound":true,"height":1080,"id":{"raw":"blue"},"quarterTurns":0,"width":1920}],"music":{"fadeIn":{"ticks":0},"fadeOut":{"ticks":0},"file":{"duration":{"ticks":6000},"fileName":"long-tone.mov","id":{"raw":"long-tone"},"title":"long-tone"},"start":{"ticks":0},"volume":1},"nextClipID":3,"nextTextID":1,"texts":[]},"version":1}';

  test('testTheLiteralOfVersionOneDecodesToTheDraftOfMusicWide', () {
    final expected = Draft(
      project: Seed.musicWide.project,
      exportSettings: const ExportSettings(size: ExportSize.uhd4K, rate: ExportRate.sixty),
      changed: DateTime.fromMillisecondsSinceEpoch(1792011909 * 1000, isUtc: true),
    );

    final draft = decodeDraft(utf8.encode(versionOne));

    expect(draft, expected);
    expect(draft.version, 1);
  });
}
