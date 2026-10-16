import 'canvas.dart';

/// What Instagram's own buttons and caption cover on a Reel, as shares of the 9:16 canvas. The bands are not
/// measured on a Reel: the Owner checks them against one of hers on the phone.
abstract final class InstagramGuide {
  /// The share of the height covered at the top.
  static const double top = 0.14;

  /// The share of the height covered at the bottom, the caption and the name.
  static const double bottom = 0.35;

  /// The share of the width covered at each side.
  static const double side = 0.06;

  /// The rectangle nothing covers, in canvas pixels from the top left. Null on the 16:9 canvas, which has no guide.
  static ({double x, double y, double width, double height})? safeArea(Canvas canvas) {
    if (canvas != Canvas.portrait) {
      return null;
    }
    final width = canvas.width.toDouble();
    final height = canvas.height.toDouble();
    return (x: width * side, y: height * top, width: width * (1 - 2 * side), height: height * (1 - top - bottom));
  }
}
