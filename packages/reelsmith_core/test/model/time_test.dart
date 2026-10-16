import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testOneSecondIs600TicksAndOneFrameIs20', () {
    expect(Time.frames(frames: 30, perSecond: 30).ticks, 600);
    expect(Time.frame.ticks, 20);
  });

  test('testFramesAreExactFor24And25And30And60', () {
    expect(Time.frames(frames: 1, perSecond: 24).ticks, 25);
    expect(Time.frames(frames: 1, perSecond: 25).ticks, 24);
    expect(Time.frames(frames: 1, perSecond: 30).ticks, 20);
    expect(Time.frames(frames: 1, perSecond: 60).ticks, 10);
    expect(Time.frames(frames: 7, perSecond: 24).ticks, 175);
    expect(Time.frames(frames: 7, perSecond: 25).ticks, 168);
    expect(Time.frames(frames: 7, perSecond: 30).ticks, 140);
    expect(Time.frames(frames: 7, perSecond: 60).ticks, 70);
  });

  test('testLessThanComparesByTicks', () {
    expect(const Time(ticks: 1) < const Time(ticks: 2), isTrue);
    expect(const Time(ticks: 2) < const Time(ticks: 1), isFalse);
    expect(const Time(ticks: 2) < const Time(ticks: 2), isFalse);
  });

  test('testMinusTakesTicksAway', () {
    expect(const Time(ticks: 4200) - const Time(ticks: 1800), const Time(ticks: 2400));
  });

  test('testRoundedDownToFrameTurns4199Into4180', () {
    expect(const Time(ticks: 4199).roundedDownToFrame, const Time(ticks: 4180));
  });

  test('testClockTextReadsMinutesAndSecondsRoundedDown', () {
    expect(const Time(ticks: 0).clockText, '00:00');
    expect(const Time(ticks: 4199).clockText, '00:06');
    expect(const Time(ticks: 4200).clockText, '00:07');
    expect(const Time(ticks: 36000).clockText, '01:00');
  });
}
