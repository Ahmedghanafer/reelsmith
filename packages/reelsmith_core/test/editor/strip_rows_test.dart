import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// The rows of the strip, unfolded as they were and folded to thin blocks.
void main() {
  test('testUnfoldedTheRowsAreTheRowsOfToday', () {
    for (final textSelected in [false, true]) {
      final rows = StripRows.of(folded: false, textSelected: textSelected);
      expect(rows.clipY, 8);
      expect(rows.clipHeight, 56);
      expect(rows.textY, 72);
      expect(rows.musicY, 100);
      expect(rows.rowHeight, 24);
    }
    expect(StripRows.of(folded: false, textSelected: false).height, 128);
    expect(StripRows.of(folded: false, textSelected: true).height, 104);
  });

  test('testFoldedTheBlocksAre24HighAndTheRowsMoveUp32', () {
    for (final textSelected in [false, true]) {
      final rows = StripRows.of(folded: true, textSelected: textSelected);
      expect(rows.clipY, 8);
      expect(rows.clipHeight, 24);
      expect(rows.textY, 40);
      expect(rows.musicY, 68);
      expect(rows.rowHeight, 24);
    }
    expect(StripRows.of(folded: true, textSelected: false).height, 96);
    expect(StripRows.of(folded: true, textSelected: true).height, 72);
  });
}
