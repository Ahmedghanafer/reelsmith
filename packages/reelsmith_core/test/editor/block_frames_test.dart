import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// The times a media's frames are made at, and which made frame each tile of a block shows. A tile is 56 points,
// as high as the clip row.
void main() {
  // A video of 30 seconds.
  const long = MediaInfo(
    id: MediaID('long'),
    fileName: 'long.mov',
    width: 1920,
    height: 1080,
    duration: Time(ticks: 18000),
    quarterTurns: 0,
    hasSound: false,
  );

  Time frameTime(Clip clip, MediaInfo media, int tile) =>
      BlockFrames.frameTime(of: clip, media: media, index: tile, tile: 56, scale: TimelineScale.standard);

  test('testBlueIsMadeAt0And600And1200', () {
    expect(BlockFrames.times(TestClip.blue.info), [0, 600, 1200].map((ticks) => Time(ticks: ticks)).toList());
  });

  test('testAPhotoIsMadeAtZeroAlone', () {
    expect(BlockFrames.times(TestPhoto.magenta.info), [Time.zero]);
  });

  test('testAMediaOf30SecondsIsMade30TimesOneASecond', () {
    final times = BlockFrames.times(long);
    expect(times.length, 30);
    expect(times.first, Time.zero);
    expect(times.last, const Time(ticks: 17400));
  });

  test('testTilesCoverTheWidth', () {
    expect(BlockFrames.tileCount(width: 180, tile: 56), 4);
    expect(BlockFrames.tileCount(width: 240, tile: 56), 5);
    expect(BlockFrames.tileCount(width: 112, tile: 56), 2);
    expect(BlockFrames.tileCount(width: 0, tile: 56), 0);
  });

  test('testATileShowsTheMadeTimeNearestTheSourceTimeUnderItsLeftEdge', () {
    final clip = Clip(
      id: const ClipID(1),
      media: long.id,
      sourceStart: const Time(ticks: 600),
      duration: const Time(ticks: 6000),
    );
    // 112 points are 1120 ticks: 600 plus 1120 is 1720, nearest 1800.
    expect(frameTime(clip, long, 2), const Time(ticks: 1800));
    // 56 points are 560 ticks: 600 plus 560 is 1160, nearest 1200.
    expect(frameTime(clip, long, 1), const Time(ticks: 1200));
    expect(frameTime(clip, long, 0), const Time(ticks: 600));
  });

  test('testATileNeverShowsPastTheLastMadeTime', () {
    const blue = TestClip.blue;
    final clip = Clip(
      id: const ClipID(1),
      media: blue.info.id,
      sourceStart: const Time(ticks: 600),
      duration: const Time(ticks: 1200),
    );
    // 600 plus 4 tiles of 560 ticks is 2840, past 1200, the last made.
    expect(frameTime(clip, blue.info, 4), const Time(ticks: 1200));
    expect(frameTime(clip, long, 40), const Time(ticks: 17400));
  });

  test('testEveryTileOfAPhotoShowsItsOneFrame', () {
    final photo = TestPhoto.magenta.info;
    final clip = Clip(id: const ClipID(1), media: photo.id, sourceStart: Time.zero, duration: MediaInfo.photoLength);
    for (var tile = 0; tile < 4; tile++) {
      expect(frameTime(clip, photo, tile), Time.zero);
    }
  });
}
