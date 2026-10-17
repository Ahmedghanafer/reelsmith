import '../model/canvas.dart';
import '../model/time.dart';
import 'timeline_geometry.dart';

abstract final class TextGeometry {
  /// The smallest font size, in canvas pixels.
  static const double minimumSize = 16;

  /// The largest font size, in canvas pixels.
  static const double maximumSize = 400;

  /// A line wraps at this share of the canvas width.
  static const double wrapShare = 0.8;

  /// No trim makes a text shorter than this.
  static const Time minimumText = TimelineGeometry.minimumClip;

  /// The Swift canvasLength(ofPoints:pictureWidth:canvas:). A length in points of the screen as canvas pixels,
  /// signed, for a picture drawn that many points wide. 0 when the picture width is not above 0.
  static double canvasLength({required double ofPoints, required double pictureWidth, required Canvas canvas}) {
    if (!(pictureWidth > 0)) {
      return 0;
    }
    return ofPoints * canvas.width / pictureWidth;
  }
}
