import '../model/framing.dart';
import '../model/project.dart';

/// The Swift enum FrameAction, one subclass per case.
sealed class FrameAction {
  const FrameAction();

  const factory FrameAction.setFit(ClipID id, Fit fit) = FrameActionSetFit;

  const factory FrameAction.setBackdrop(ClipID id, Backdrop backdrop) = FrameActionSetBackdrop;

  /// Held 1 to 4, offset held again.
  const factory FrameAction.setZoom(ClipID id, double zoom) = FrameActionSetZoom;

  /// Held by rule 84.
  const factory FrameAction.setOffset(ClipID id, double x, double y) = FrameActionSetOffset;

  /// Every clip takes the fit and the backdrop of the named clip and keeps its zoom and offset, held again.
  const factory FrameAction.applyToAll(ClipID id) = FrameActionApplyToAll;
}

final class FrameActionSetFit extends FrameAction {
  final ClipID id;
  final Fit fit;

  const FrameActionSetFit(this.id, this.fit);

  FrameActionSetFit copyWith({ClipID? id, Fit? fit}) => FrameActionSetFit(id ?? this.id, fit ?? this.fit);

  @override
  bool operator ==(Object other) => other is FrameActionSetFit && other.id == id && other.fit == fit;

  @override
  int get hashCode => Object.hash(FrameActionSetFit, id, fit);
}

final class FrameActionSetBackdrop extends FrameAction {
  final ClipID id;
  final Backdrop backdrop;

  const FrameActionSetBackdrop(this.id, this.backdrop);

  FrameActionSetBackdrop copyWith({ClipID? id, Backdrop? backdrop}) =>
      FrameActionSetBackdrop(id ?? this.id, backdrop ?? this.backdrop);

  @override
  bool operator ==(Object other) =>
      other is FrameActionSetBackdrop && other.id == id && other.backdrop == backdrop;

  @override
  int get hashCode => Object.hash(FrameActionSetBackdrop, id, backdrop);
}

final class FrameActionSetZoom extends FrameAction {
  final ClipID id;
  final double zoom;

  const FrameActionSetZoom(this.id, this.zoom);

  FrameActionSetZoom copyWith({ClipID? id, double? zoom}) => FrameActionSetZoom(id ?? this.id, zoom ?? this.zoom);

  @override
  bool operator ==(Object other) => other is FrameActionSetZoom && other.id == id && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(FrameActionSetZoom, id, zoom);
}

final class FrameActionSetOffset extends FrameAction {
  final ClipID id;
  final double x;
  final double y;

  const FrameActionSetOffset(this.id, this.x, this.y);

  FrameActionSetOffset copyWith({ClipID? id, double? x, double? y}) =>
      FrameActionSetOffset(id ?? this.id, x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) => other is FrameActionSetOffset && other.id == id && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(FrameActionSetOffset, id, x, y);
}

final class FrameActionApplyToAll extends FrameAction {
  final ClipID id;

  const FrameActionApplyToAll(this.id);

  FrameActionApplyToAll copyWith({ClipID? id}) => FrameActionApplyToAll(id ?? this.id);

  @override
  bool operator ==(Object other) => other is FrameActionApplyToAll && other.id == id;

  @override
  int get hashCode => Object.hash(FrameActionApplyToAll, id);
}
