import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testTheStandardIsSixtyAndGivesWhatTheStaticFunctionsGive', () {
    final standard = TimelineScale.standard;
    expect(standard.pointsPerSecond, 60);
    // The times and points of timeline_geometry_test.dart.
    expect(standard.x(const Time(ticks: 1800)), TimelineGeometry.x(const Time(ticks: 1800)));
    expect(standard.width(const Time(ticks: 2400)), TimelineGeometry.width(const Time(ticks: 2400)));
    expect(standard.time(121), TimelineGeometry.time(121));
    expect(standard.time(-61), TimelineGeometry.time(-61));
    expect(standard.trimAmount(60), TimelineGeometry.trimAmount(60));
    expect(standard.trimAmount(-61), TimelineGeometry.trimAmount(-61));
  });

  test('testAtOneHundredAndTwentyPointsASecond', () {
    final scale = TimelineScale(pointsPerSecond: 120);
    expect(scale.x(const Time(ticks: 600)), 120);
    expect(scale.trimAmount(-61), const Time(ticks: -300));
  });

  test('testAZoomIsHeldBetweenTenAndTwoHundredAndForty', () {
    expect(TimelineScale.least, 10);
    expect(TimelineScale.most, 240);
    expect(TimelineScale.standard.zoomed(100).pointsPerSecond, 240);
    expect(TimelineScale.standard.zoomed(0.001).pointsPerSecond, 10);
  });

  test('testAFactorThatIsNotAboveZeroOrNotFiniteGivesTheScaleUnchanged', () {
    final scale = TimelineScale(pointsPerSecond: 120);
    for (final factor in [0.0, -1.0, double.infinity, double.negativeInfinity, double.nan]) {
      expect(scale.zoomed(factor), scale, reason: '$factor');
    }
  });
}
