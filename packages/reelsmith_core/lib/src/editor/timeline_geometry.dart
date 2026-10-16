import 'dart:math';

import '../model/time.dart';

/// Where a time sits on the timeline strip, in points, at the scale of 60 points a second.
abstract final class TimelineGeometry {
  static const double pointsPerSecond = 60;

  /// 60 ticks, a tenth of a second.
  static const Time minimumClip = Time(ticks: 60);

  /// The Swift x(of:).
  static double x(Time time) => TimelineScale.standard.x(time);

  /// The Swift time(atX:). Rounded down to a frame, never below zero.
  static Time time(double x) => TimelineScale.standard.time(x);

  /// The Swift width(of:).
  static double width(Time duration) => TimelineScale.standard.width(duration);

  /// The Swift trimAmount(forDragOf:). Whole frames, signed, rounded toward zero: minus 61 points give minus 600
  /// ticks.
  static Time trimAmount(double points) => TimelineScale.standard.trimAmount(points);

  /// Where the writing of a text bar begins and how wide it may be: from 6 points right of the left end
  /// of the part of the bar that is on the screen to 6 points left of the right end of that part.
  /// `shownX` and `shownWidth` are the part of the strip row that is on the screen, in the points of
  /// `barX`, and so is the x that comes back. The width is 0 for a bar with no part on the screen
  /// and for a part narrower than 12 points.
  static ({double x, double width}) writing({
    required double barX,
    required double barWidth,
    required double shownX,
    required double shownWidth,
  }) {
    const double inset = 6;
    final left = _max(barX, shownX);
    final right = _min(barX + barWidth, shownX + shownWidth);
    return (x: left + inset, width: _max(right - left - 2 * inset, 0));
  }
}

/// Swift's min: the second when it is less than the first, else the first.
double _min(double a, double b) => b < a ? b : a;

/// Swift's max: the second when it is at least the first, else the first.
double _max(double a, double b) => b >= a ? b : a;

/// The rows of the timeline strip, in points from its top: the clips, the texts under them and, while no text is
/// selected, the music. Folded, the blocks are 24 points high and every row under them moves up 32.
class StripRows {
  final double clipY;
  final double clipHeight;
  final double textY;
  final double musicY;

  /// The height of the text row and of the music row.
  final double rowHeight;

  /// The whole strip: 8 points under the text row with a selected text, 4 under the music row without.
  final double height;

  const StripRows({
    required this.clipY,
    required this.clipHeight,
    required this.textY,
    required this.musicY,
    required this.rowHeight,
    required this.height,
  });

  static StripRows of({required bool folded, required bool textSelected}) {
    final double clipHeight = folded ? 24 : 56;
    final textY = 8 + clipHeight + 8;
    final musicY = textY + 24 + 4;
    return StripRows(
      clipY: 8,
      clipHeight: clipHeight,
      textY: textY,
      musicY: musicY,
      rowHeight: 24,
      height: textSelected ? textY + 24 + 8 : musicY + 24 + 4,
    );
  }
}

/// The scale of the timeline strip, held between `least` and `most` points a second.
class TimelineScale {
  final double pointsPerSecond;

  /// The Swift init(pointsPerSecond:), which holds the value between least and most.
  factory TimelineScale({required double pointsPerSecond}) =>
      TimelineScale._(min(max(pointsPerSecond, TimelineScale.least), TimelineScale.most));

  const TimelineScale._(this.pointsPerSecond);

  static const TimelineScale standard = TimelineScale._(60);
  static const double least = 10;
  static const double most = 240;

  /// The Swift zoomed(by:). Times the factor, held. A factor that is not finite or not above 0 gives the scale
  /// unchanged.
  TimelineScale zoomed(double factor) {
    if (!(factor.isFinite && factor > 0)) {
      return this;
    }
    return TimelineScale(pointsPerSecond: pointsPerSecond * factor);
  }

  /// The Swift x(of:).
  double x(Time time) => time.ticks * pointsPerSecond / 600;

  /// The Swift time(atX:). Rounded down to a frame, never below zero.
  Time time(double x) => Time(ticks: (max(x, 0.0) * 600 / pointsPerSecond).toInt()).roundedDownToFrame;

  /// The Swift width(of:).
  double width(Time duration) => x(duration);

  /// The Swift trimAmount(forDragOf:). Whole frames, signed, rounded toward zero.
  Time trimAmount(double points) {
    final ticks = (points * 600 / pointsPerSecond).toInt();
    return Time(ticks: ticks ~/ Time.frame.ticks * Time.frame.ticks);
  }

  /// As Swift's stored var, which is not held again when it is set.
  TimelineScale copyWith({double? pointsPerSecond}) => TimelineScale._(pointsPerSecond ?? this.pointsPerSecond);

  @override
  bool operator ==(Object other) => other is TimelineScale && other.pointsPerSecond == pointsPerSecond;

  @override
  int get hashCode => pointsPerSecond.hashCode;
}
