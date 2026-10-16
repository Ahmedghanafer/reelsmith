// How the picture of a clip stands on the canvas: fit or fill, the backdrop of its bars, a zoom and an offset.

import 'dart:math';

import 'canvas.dart';

enum Fit {
  /// Whole inside the canvas.
  fit('fit'),

  /// Covering the canvas.
  fill('fill');

  final String rawValue;

  const Fit(this.rawValue);
}

enum Backdrop {
  black('black'),

  /// The picture itself, filling the canvas and blurred, under the bars.
  blurred('blurred');

  final String rawValue;

  const Backdrop(this.rawValue);
}

class Framing {
  final Fit fit;
  final Backdrop backdrop;

  /// 1 to 4.
  final double zoom;

  /// The picture's centre from the canvas centre, a share of the canvas width.
  final double x;

  /// The same, a share of the canvas height, positive down.
  final double y;

  const Framing({this.fit = Fit.fit, this.backdrop = Backdrop.black, this.zoom = 1, this.x = 0, this.y = 0});

  /// Fit, black, zoom 1, centred: the placement of every clip before framing.
  static const Framing standard = Framing();
  static const double leastZoom = 1;
  static const double mostZoom = 4;

  /// The zoom held from 1 to 4, then on each axis the offset held so the picture's near edge lies between
  /// min(0, W minus w) and max(0, W minus w), for a picture of that upright size on the canvas (rule 84).
  /// An offset inside its limits is kept as it is.
  Framing held({required double uprightWidth, required double uprightHeight, required Canvas canvas}) {
    final heldZoom = min(max(zoom, Framing.leastZoom), Framing.mostZoom);
    final width = canvas.width.toDouble();
    final height = canvas.height.toDouble();
    final size = copyWith(
      zoom: heldZoom,
    ).size(uprightWidth: uprightWidth, uprightHeight: uprightHeight, width: width, height: height);
    return copyWith(
      zoom: heldZoom,
      x: _heldShare(x, picture: size.width, canvas: width),
      y: _heldShare(y, picture: size.height, canvas: height),
    );
  }

  /// The fit size (whole inside width by height) or the fill size (covering it), times the zoom. The side that
  /// limits takes the width or the height itself, so the standard framing gives the fit of before to the bit.
  ({double width, double height}) size({
    required double uprightWidth,
    required double uprightHeight,
    required double width,
    required double height,
  }) {
    var sizeWidth = width;
    var sizeHeight = height;
    final wider = uprightWidth * height > uprightHeight * width;
    if (wider == (fit == Fit.fit)) {
      sizeHeight = uprightHeight * width / uprightWidth;
    } else {
      sizeWidth = uprightWidth * height / uprightHeight;
    }
    return (width: sizeWidth * zoom, height: sizeHeight * zoom);
  }

  Framing copyWith({Fit? fit, Backdrop? backdrop, double? zoom, double? x, double? y}) => Framing(
    fit: fit ?? this.fit,
    backdrop: backdrop ?? this.backdrop,
    zoom: zoom ?? this.zoom,
    x: x ?? this.x,
    y: y ?? this.y,
  );

  @override
  bool operator ==(Object other) =>
      other is Framing &&
      other.fit == fit &&
      other.backdrop == backdrop &&
      other.zoom == zoom &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(fit, backdrop, zoom, x, y);
}

/// The near edge of a picture of that length on that axis, centred plus the share of the canvas, held between
/// min(0, canvas minus picture) and max(0, canvas minus picture).
double nearEdge(double share, {required double picture, required double canvas}) {
  final edge = (canvas - picture) / 2 + share * canvas;
  return min(max(edge, min(0.0, canvas - picture)), max(0.0, canvas - picture));
}

/// The share kept when its edge lies inside the limits, else the share of the held edge.
double _heldShare(double share, {required double picture, required double canvas}) {
  final middle = (canvas - picture) / 2;
  final edge = middle + share * canvas;
  final held = nearEdge(share, picture: picture, canvas: canvas);
  return held == edge ? share : (held - middle) / canvas;
}
