import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  final project = Seed.threeClips.project;

  test('testStartsComeFromTheClipLengths', () {
    expect(project.start(const ClipID(1)), const Time(ticks: 0));
    expect(project.start(const ClipID(2)), const Time(ticks: 1800));
    expect(project.start(const ClipID(3)), const Time(ticks: 4200));
  });

  test('testDurationIsTheSumOfTheClipLengths', () {
    expect(project.duration, const Time(ticks: 5400));
  });

  test('testClipAtAJoinIsTheLaterOneAndNoneAtTheEnd', () {
    expect(project.clip(const Time(ticks: 1800))?.media, const MediaID('red'));
    expect(project.clip(const Time(ticks: 5400)), isNull);
  });

  test('testPositionOfTheFirstClipIs1', () {
    expect(project.positionOfClip(const ClipID(1)), 1);
  });
}
