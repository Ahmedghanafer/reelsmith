import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../engine/video_engine.dart';

/// The frames of each media of one strip, kept in memory while the strip lives, so an editor makes them once per
/// media while it is open, as `FramesCache.swift` did. They come from `blockFrames` as PNG bytes and are decoded
/// here, never written into `Media`.
///
/// https://api.flutter.dev/flutter/painting/decodeImageFromList.html
/// https://api.flutter.dev/flutter/dart-ui/Image/dispose.html
/// https://api.dart.dev/stable/dart-async/Future/wait.html
class FramesCache {
  FramesCache({required this.engine, required this.mediaFolder, required this.changed});

  final VideoEngine engine;
  final String mediaFolder;

  /// Called when the frames of a media come, to draw them.
  final void Function() changed;

  final Map<core.MediaID, Map<core.Time, ui.Image>> _made = {};
  final Set<core.MediaID> _asked = {};
  bool _disposed = false;

  /// The media whose frames came.
  int get madeCount => _made.values.where((frames) => frames.isNotEmpty).length;

  /// The frames of the media by their time, or null while they are made. The first ask starts making them. A media
  /// whose frames cannot be made, because `blockFrames` throws or a frame does not decode, has none, as in `m6`, and
  /// is not asked for again.
  Map<core.Time, ui.Image>? frames(core.MediaInfo media) {
    final made = _made[media.id];
    if (made != null) {
      return made;
    }
    if (_asked.add(media.id)) {
      _make(media);
    }
    return null;
  }

  Future<void> _make(core.MediaInfo media) async {
    var frames = <core.Time, ui.Image>{};
    try {
      final bytes = await engine.blockFrames(jsonEncode(_mediaJson(media)), mediaFolder);
      final times = bytes.keys.toList();
      // A frame that does not decode lets go of those that did.
      final images = await Future.wait(
        [for (final time in times) decodeImageFromList(bytes[time]!)],
        cleanUp: (image) => image.dispose(),
      );
      frames = {for (final (index, time) in times.indexed) core.Time(ticks: time): images[index]};
    } catch (error) {
      print('strip: the frames of a block were not made: $error');
    }
    // A strip gone while they were made draws nothing more.
    if (_disposed) {
      for (final image in frames.values) {
        image.dispose();
      }
      return;
    }
    _made[media.id] = frames;
    changed();
  }

  /// Lets every frame go. Called when the strip goes.
  void dispose() {
    _disposed = true;
    for (final frames in _made.values) {
      for (final image in frames.values) {
        image.dispose();
      }
    }
    _made.clear();
  }
}

/// The media fact as the Swift decoder of `MediaInfo` reads it.
Map<String, Object?> _mediaJson(core.MediaInfo media) => {
  'id': {'raw': media.id.raw},
  'fileName': media.fileName,
  'width': media.width,
  'height': media.height,
  'duration': {'ticks': media.duration.ticks},
  'quarterTurns': media.quarterTurns,
  'hasSound': media.hasSound,
  'kind': media.kind.rawValue,
};
