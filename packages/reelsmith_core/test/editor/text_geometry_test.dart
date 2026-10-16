import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

import '../model/text_model_test.dart' show textItem;

void main() {
  const one = TextID(1);
  const two = TextID(2);

  /// The landscape project of two clips with two texts that are not blank, at the two centres.
  Project twoTexts(double firstX, double firstY, double secondX, double secondY) {
    final first = textItem(1, 'a', TextSpan.whole).copyWith(x: firstX, y: firstY);
    final second = textItem(2, 'b', TextSpan.whole).copyWith(x: secondX, y: secondY);
    return Seed.twoClipsWide.project.copyWith(texts: [first, second], nextTextID: 3);
  }

  test('testTheLimitsOfATextSizeAndOfATextLength', () {
    expect(TextGeometry.minimumSize, 16);
    expect(TextGeometry.maximumSize, 400);
    expect(TextGeometry.wrapShare, 0.8);
    expect(TextGeometry.minimumText, const Time(ticks: 60));
    expect(TextGeometry.minimumText, TimelineGeometry.minimumClip);
  });

  test('testPointsOfThePictureBecomeCanvasPixels', () {
    expect(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: 400, canvas: Canvas.landscape), 480);
    expect(TextGeometry.canvasLength(ofPoints: -100, pictureWidth: 400, canvas: Canvas.landscape), -480);
    expect(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: 400, canvas: Canvas.portrait), 270);
  });

  test('testAPictureWithNoWidthGivesNoLength', () {
    expect(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: 0, canvas: Canvas.landscape), 0);
    expect(TextGeometry.canvasLength(ofPoints: 100, pictureWidth: -400, canvas: Canvas.landscape), 0);
  });

  test('testTheOneTextIsTheNearestFromAnyPlace', () {
    expect(Seed.textWide.project.textNearest(nearestToX: 0, y: 0, at: Time.zero), one);
  });

  test('testTheNearestOfTwoTextsSideBySide', () {
    final project = twoTexts(400, 540, 1500, 540);

    expect(project.textNearest(nearestToX: 500, y: 540, at: Time.zero), one);
    expect(project.textNearest(nearestToX: 1400, y: 540, at: Time.zero), two);
    expect(project.textNearest(nearestToX: 949, y: 540, at: Time.zero), one);
    expect(project.textNearest(nearestToX: 951, y: 540, at: Time.zero), two);
  });

  test('testTheNearestOfTwoTextsOneAboveTheOther', () {
    final project = twoTexts(960, 100, 960, 900);

    expect(project.textNearest(nearestToX: 960, y: 200, at: Time.zero), one);
    expect(project.textNearest(nearestToX: 960, y: 800, at: Time.zero), two);
  });

  test('testTheLaterTextOfTheListWinsATie', () {
    expect(twoTexts(960, 540, 960, 540).textNearest(nearestToX: 100, y: 100, at: Time.zero), two);
    expect(twoTexts(400, 540, 1500, 540).textNearest(nearestToX: 950, y: 540, at: Time.zero), two);
  });

  test('testABlankTextIsNeverTheNearest', () {
    var project = twoTexts(400, 540, 1500, 540);
    project = project.copyWith(texts: [project.texts[0], project.texts[1].copyWith(string: ' \n')]);

    expect(project.textNearest(nearestToX: 1500, y: 540, at: Time.zero), one);

    project = project.copyWith(texts: [project.texts[0].copyWith(string: ''), project.texts[1]]);

    expect(project.textNearest(nearestToX: 1500, y: 540, at: Time.zero), isNull);
  });

  test('testOnlyATextWhoseRangeHoldsTheTimeIsGiven', () {
    final project = Seed.textBoxWide.project;

    expect(project.textNearest(nearestToX: 960, y: 540, at: const Time(ticks: 580)), isNull);
    expect(project.textNearest(nearestToX: 960, y: 540, at: const Time(ticks: 599)), isNull);
    expect(project.textNearest(nearestToX: 960, y: 540, at: const Time(ticks: 600)), one);
    expect(project.textNearest(nearestToX: 960, y: 540, at: const Time(ticks: 1480)), one);
    expect(project.textNearest(nearestToX: 960, y: 540, at: const Time(ticks: 1499)), one);
    expect(project.textNearest(nearestToX: 960, y: 540, at: const Time(ticks: 1500)), isNull);
  });

  test('testAProjectWithNoTextHasNoNearestText', () {
    expect(Seed.twoClipsWide.project.textNearest(nearestToX: 960, y: 540, at: Time.zero), isNull);
  });
}
