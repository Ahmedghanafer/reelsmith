import 'dart:math';

import '../model/media.dart';
import '../model/project.dart';
import '../model/time.dart';
import 'timeline_geometry.dart';

/// The frames along a block of the strip: the times a media's frames are made at, how many square tiles a block
/// holds, and which made frame each tile shows.
abstract final class BlockFrames {
  /// 600 ticks, one second.
  static const Time step = Time(ticks: 600);

  /// The Swift times(of:). 0, step, and on, below the duration. [0] for a photo.
  static List<Time> times(MediaInfo media) {
    if (media.kind == MediaKind.photo) {
      return [Time.zero];
    }
    return [for (var ticks = 0; ticks < media.duration.ticks; ticks += step.ticks) Time(ticks: ticks)];
  }

  /// Whole tiles that cover the width, 0 for 0.
  static int tileCount({required double width, required double tile}) {
    if (!(width.isFinite && tile.isFinite && width > 0 && tile > 0)) {
      return 0;
    }
    return (width / tile).ceil();
  }

  /// The Swift frameTime(of:media:tile:tile:scale:), whose first `tile` is the index of the tile. The made time
  /// nearest the source time under the tile's left edge, never past the last made.
  static Time frameTime({
    required Clip of,
    required MediaInfo media,
    required int index,
    required double tile,
    required TimelineScale scale,
  }) {
    // The count of `times`, without making the list for every tile.
    final made = media.kind == MediaKind.photo ? 1 : (media.duration.ticks + step.ticks - 1) ~/ step.ticks;
    final source = of.sourceStart.ticks + index * tile * 600 / scale.pointsPerSecond;
    if (!(made > 1 && source.isFinite)) {
      return Time.zero;
    }
    final nearest = min(max((source / step.ticks).roundToDouble(), 0.0), (made - 1).toDouble());
    return Time(ticks: nearest.toInt() * step.ticks);
  }
}
