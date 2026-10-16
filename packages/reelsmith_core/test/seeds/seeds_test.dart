import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testTheFiveTestClipsHoldTheValuesOfTheTable', () {
    const blue = RGB(r: 0, g: 0, b: 255);
    const red = RGB(r: 255, g: 0, b: 0);
    const green = RGB(r: 0, g: 255, b: 0);
    const white = RGB(r: 255, g: 255, b: 255);
    const yellow = RGB(r: 255, g: 255, b: 0);

    expect(
      TestClip.blue,
      const TestClip(
        name: 'blue',
        storedWidth: 1920,
        storedHeight: 1080,
        duration: Time(ticks: 1800),
        framesPerSecond: 30,
        quarterTurns: 0,
        hasSound: true,
        left: blue,
        right: blue,
      ),
    );
    expect(
      TestClip.red,
      const TestClip(
        name: 'red',
        storedWidth: 1080,
        storedHeight: 1920,
        duration: Time(ticks: 2400),
        framesPerSecond: 30,
        quarterTurns: 0,
        hasSound: true,
        left: red,
        right: red,
      ),
    );
    expect(
      TestClip.green,
      const TestClip(
        name: 'green',
        storedWidth: 1080,
        storedHeight: 1920,
        duration: Time(ticks: 1200),
        framesPerSecond: 30,
        quarterTurns: 0,
        hasSound: false,
        left: green,
        right: green,
      ),
    );
    expect(
      TestClip.turned,
      const TestClip(
        name: 'turned',
        storedWidth: 1920,
        storedHeight: 1080,
        duration: Time(ticks: 1200),
        framesPerSecond: 30,
        quarterTurns: 1,
        hasSound: false,
        left: white,
        right: blue,
      ),
    );
    expect(
      TestClip.fast,
      const TestClip(
        name: 'fast',
        storedWidth: 1080,
        storedHeight: 1920,
        duration: Time(ticks: 1200),
        framesPerSecond: 60,
        quarterTurns: 0,
        hasSound: false,
        left: yellow,
        right: yellow,
      ),
    );
    expect(TestClip.all, [TestClip.blue, TestClip.red, TestClip.green, TestClip.turned, TestClip.fast]);
  });

  test('testInfoGivesEachClipTheIdAndTheFileOfItsName', () {
    expect(TestClip.all.map((clip) => clip.info.id.raw).toList(), ['blue', 'red', 'green', 'turned', 'fast']);
    expect(TestClip.all.map((clip) => clip.info.fileName).toList(), [
      'blue.mov',
      'red.mov',
      'green.mov',
      'turned.mov',
      'fast.mov',
    ]);
    expect(
      TestClip.turned.info,
      const MediaInfo(
        id: MediaID('turned'),
        fileName: 'turned.mov',
        width: 1920,
        height: 1080,
        duration: Time(ticks: 1200),
        quarterTurns: 1,
        hasSound: false,
      ),
    );
  });

  test('testTheEmptySeedHasNoClips', () {
    expect(Seed.empty.testClips, <TestClip>[]);
    expect(Seed.empty.project.clips, <Clip>[]);
  });

  test('testTwoClipsIsBlueThenRed', () {
    expect(Seed.twoClips.testClips, [TestClip.blue, TestClip.red]);
    expect(Seed.twoClips.project.clips.map((clip) => clip.media).toList(), [
      const MediaID('blue'),
      const MediaID('red'),
    ]);
    expect(Seed.twoClips.project.duration, const Time(ticks: 4200));
  });

  test('testThreeClipsIsBlueRedGreen', () {
    expect(Seed.threeClips.testClips, [TestClip.blue, TestClip.red, TestClip.green]);
    expect(Seed.threeClips.project.clips.map((clip) => clip.media).toList(), [
      const MediaID('blue'),
      const MediaID('red'),
      const MediaID('green'),
    ]);
    expect(Seed.threeClips.project.duration, const Time(ticks: 5400));
  });

  test('testAnUnknownSeedNameAnswersNil', () {
    expect(Seed.fromRawValue('four-clips'), isNull);
  });

  test('testSeedProjectsCountTheirClipIdsFrom1', () {
    expect(Seed.empty.project.nextClipID, 1);
    expect(Seed.twoClips.project.clips.map((clip) => clip.id).toList(), [const ClipID(1), const ClipID(2)]);
    expect(Seed.twoClips.project.nextClipID, 3);
    expect(Seed.threeClips.project.clips.map((clip) => clip.id).toList(), [
      const ClipID(1),
      const ClipID(2),
      const ClipID(3),
    ]);
    expect(Seed.threeClips.project.nextClipID, 4);
  });
}
