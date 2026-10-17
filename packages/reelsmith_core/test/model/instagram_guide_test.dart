import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the safe area of the Instagram guide in canvas pixels: the 9:16 canvas less 0.14 of its height at the top,
// 0.35 at the bottom and 0.06 of its width at each side, and none on the 16:9 canvas.
void main() {
  test('testTheSafeAreaOfThePortraitCanvas', () {
    final safe = InstagramGuide.safeArea(Canvas.portrait);
    expect(safe, isNotNull);
    expect(safe!.x, closeTo(64.8, 0.000001));
    expect(safe.y, closeTo(268.8, 0.000001));
    expect(safe.width, closeTo(950.4, 0.000001));
    expect(safe.height, closeTo(979.2, 0.000001));
  });

  test('testTheLandscapeCanvasHasNoSafeArea', () {
    expect(InstagramGuide.safeArea(Canvas.landscape), isNull);
  });
}
