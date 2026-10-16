import '../model/time.dart';
import 'timeline_geometry.dart';

abstract final class TextGeometry {
  /// The smallest font size, in canvas pixels.
  static const double minimumSize = 16;

  /// The largest font size, in canvas pixels.
  static const double maximumSize = 400;

  /// No trim makes a text shorter than this.
  static const Time minimumText = TimelineGeometry.minimumClip;
}
