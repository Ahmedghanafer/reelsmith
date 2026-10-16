import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testTheScaleAndTheShortestClip', () {
    expect(TimelineGeometry.pointsPerSecond, 60);
    expect(TimelineGeometry.minimumClip, const Time(ticks: 60));
  });

  test('testXOfATime', () {
    expect(TimelineGeometry.x(const Time(ticks: 1800)), 180);
  });

  test('testWidthOfALength', () {
    expect(TimelineGeometry.width(const Time(ticks: 2400)), 240);
  });

  test('testTimeAtXRoundsDownToAFrameAndNeverGoesBelowZero', () {
    expect(TimelineGeometry.time(121), const Time(ticks: 1200));
    expect(TimelineGeometry.time(-61), Time.zero);
  });

  test('testTrimAmountIsWholeFramesRoundedTowardZero', () {
    expect(TimelineGeometry.trimAmount(60), const Time(ticks: 600));
    expect(TimelineGeometry.trimAmount(-61), const Time(ticks: -600));
  });

  // The writing of a text bar, on a screen from x 0 to x 402.

  test('testTheWritingOfABarWhollyOnTheScreenIsSixPointsInsideBothEnds', () {
    final writing = TimelineGeometry.writing(barX: 261, barWidth: 90, shownX: 0, shownWidth: 402);
    expect(writing.x, 267);
    expect(writing.width, 78);
  });

  test('testTheWritingOfABarThatBeginsLeftOfTheScreenBeginsSixPointsInsideTheScreen', () {
    // The bar ends at x 201.
    final writing = TimelineGeometry.writing(barX: -99, barWidth: 300, shownX: 0, shownWidth: 402);
    expect(writing.x, 6);
    expect(writing.width, 189);
  });

  test('testTheWritingOfABarThatEndsRightOfTheScreenEndsSixPointsInsideTheScreen', () {
    final writing = TimelineGeometry.writing(barX: 201, barWidth: 420, shownX: 0, shownWidth: 402);
    expect(writing.x, 207);
    expect(writing.width, 189);
  });

  test('testTheWritingOfABarWiderThanTheScreenOnBothSidesIsSixPointsInsideTheScreen', () {
    final writing = TimelineGeometry.writing(barX: -99, barWidth: 900, shownX: 0, shownWidth: 402);
    expect(writing.x, 6);
    expect(writing.width, 390);
    // A part of the row that does not begin at 0.
    final moved = TimelineGeometry.writing(barX: -99, barWidth: 900, shownX: 10, shownWidth: 402);
    expect(moved.x, 16);
    expect(moved.width, 390);
  });

  test('testTheWritingHasNoWidthOffTheScreenAndBelowTwelvePoints', () {
    // Right of the screen, left of it, the shortest bar, a bar of 11 points, 7 points of a bar on the screen.
    expect(TimelineGeometry.writing(barX: 500, barWidth: 100, shownX: 0, shownWidth: 402).width, 0);
    expect(TimelineGeometry.writing(barX: -200, barWidth: 100, shownX: 0, shownWidth: 402).width, 0);
    expect(TimelineGeometry.writing(barX: 100, barWidth: 6, shownX: 0, shownWidth: 402).width, 0);
    expect(TimelineGeometry.writing(barX: 100, barWidth: 11, shownX: 0, shownWidth: 402).width, 0);
    expect(TimelineGeometry.writing(barX: 395, barWidth: 100, shownX: 0, shownWidth: 402).width, 0);
    // 13 points give 1.
    expect(TimelineGeometry.writing(barX: 100, barWidth: 13, shownX: 0, shownWidth: 402).width, 1);
  });
}
