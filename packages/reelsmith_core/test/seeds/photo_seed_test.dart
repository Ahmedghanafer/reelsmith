import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

// Holds the test photo and the seed `photo-wide`.
void main() {
  test('testTheTestPhotoMagentaHoldsItsValues', () {
    const magenta = TestPhoto.magenta;

    expect(magenta.name, 'magenta');
    expect(magenta.width, 1080);
    expect(magenta.height, 1440);
    expect(magenta.colour, const RGB(r: 255, g: 0, b: 255));
  });

  test('testTheInfoOfATestPhotoIsComputedFromItsOwnValues', () {
    final photo = TestPhoto.magenta.copyWith(name: 'other', width: 640, height: 480);

    expect(
      TestPhoto.magenta.info,
      const MediaInfo(
        id: MediaID('magenta'),
        fileName: 'magenta.mov',
        width: 1080,
        height: 1440,
        duration: MediaInfo.photoLongest,
        quarterTurns: 0,
        hasSound: false,
        kind: MediaKind.photo,
      ),
    );
    expect(
      photo.info,
      const MediaInfo(
        id: MediaID('other'),
        fileName: 'other.mov',
        width: 640,
        height: 480,
        duration: MediaInfo.photoLongest,
        quarterTurns: 0,
        hasSound: false,
        kind: MediaKind.photo,
      ),
    );
  });

  test('testPhotoWideIsBlueTheMagentaPhotoAndRedOnTheLandscapeCanvas', () {
    const seed = Seed.photoWide;
    final project = seed.project;

    expect(Seed.fromRawValue('photo-wide'), Seed.photoWide);
    expect(seed.canvas, Canvas.landscape);
    expect(project.canvas, Canvas.landscape);
    expect(seed.testClips, [TestClip.blue, TestClip.red]);
    expect(seed.testPhotos, [TestPhoto.magenta]);
    expect(project.clips, const [
      Clip(id: ClipID(1), media: MediaID('blue'), sourceStart: Time.zero, duration: Time(ticks: 1800)),
      Clip(id: ClipID(2), media: MediaID('magenta'), sourceStart: Time.zero, duration: Time(ticks: 1800)),
      Clip(id: ClipID(3), media: MediaID('red'), sourceStart: Time.zero, duration: Time(ticks: 2400)),
    ]);
    expect(project.nextClipID, 4);
    expect(project.duration, const Time(ticks: 6000));
    expect(project.media, {
      const MediaID('blue'): TestClip.blue.info,
      const MediaID('magenta'): TestPhoto.magenta.info,
      const MediaID('red'): TestClip.red.info,
    });
    expect(project.fileNames, ['blue.mov', 'magenta.mov', 'red.mov']);
    expect(project.texts, <TextItem>[]);
    expect(project.music, isNull);
    expect(seed.selectedText, isNull);
    expect(seed.testTones, <TestTone>[]);
    expect(seed.showsSound, isFalse);
  });

  test('testEveryOtherSeedHasNoTestPhotoAndNoPhoto', () {
    for (final seed in Seed.allCases.where((seed) => seed != Seed.photoWide)) {
      expect(seed.testPhotos, <TestPhoto>[], reason: seed.rawValue);
      for (final info in seed.project.media.values) {
        expect(info.kind, MediaKind.video, reason: seed.rawValue);
      }
      for (final clip in seed.project.clips) {
        expect(clip.volume, 1, reason: seed.rawValue);
      }
    }
  });
}
