import 'package:flutter/widgets.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';

/// The Instagram guide over the picture while `showsGuide` holds and the canvas has a guide: a tint outside the safe
/// area, and the safe area itself, outlined, the element `editor.guide.safe` inside the container `editor.guide`. The
/// screen draws it over the picture, so it is never in a plan, a cover or an export, and it takes no touch: the
/// gestures on the picture go through it. Left to right whatever the language, as the picture.
///
/// https://api.flutter.dev/flutter/widgets/IgnorePointer-class.html
/// https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
/// https://api.flutter.dev/flutter/widgets/Positioned-class.html
/// https://api.flutter.dev/flutter/widgets/CustomPaint-class.html
/// https://api.flutter.dev/flutter/dart-ui/PathFillType.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class InstagramGuideView extends StatelessWidget {
  const InstagramGuideView({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final canvas = store.state.project.canvas;
        final safe = core.InstagramGuide.safeArea(canvas);
        if (!store.showsGuide || safe == null) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The picture has the shape of the canvas, so its width gives the scale of both axes.
                final scale = constraints.maxWidth / canvas.width;
                final hole = Rect.fromLTWH(safe.x * scale, safe.y * scale, safe.width * scale, safe.height * scale);
                return Semantics(
                  identifier: 'editor.guide',
                  container: true,
                  explicitChildNodes: true,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _Tint(hole))),
                      Positioned.fromRect(
                        rect: hole,
                        child: Semantics(
                          identifier: 'editor.guide.safe',
                          container: true,
                          label: words.text(core.Words('clip.guide')),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Black at 0.4 outside the hole, and a white line at 0.6 inside the hole's edge, so the line stays within the safe
/// area. Over the picture, which is drawn in its own colours in light and dark alike.
class _Tint extends CustomPainter {
  _Tint(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final tint = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(hole);
    canvas.drawPath(tint, Paint()..color = const Color(0x66000000));
    canvas.drawRect(
      hole.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x99FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_Tint old) => old.hole != hole;
}
