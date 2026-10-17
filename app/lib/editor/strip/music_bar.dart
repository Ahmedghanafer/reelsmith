import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_screen.dart';
import '../editor_store.dart';
import 'clip_press.dart';

/// The music row of the strip, for the slot `music-row`, `left` being the x of time zero and `shownWidth` the width
/// of the strip on the screen. One bar from time zero to the end of the heard music, under the text row, none with
/// no heard music or while a text is selected, so the picture keeps its room above the keyboard of the text panel.
/// Placed by the state the strip draws, so it follows a trim while a handle drags. It decides nothing: the place and
/// the width come from the scale of the strip, the length from `Project.heardMusic`. Never mirrored.
List<Widget> musicBar({
  required EditorStore store,
  required core.TimelineScale scale,
  required core.StripRows rows,
  required double left,
  required double shownWidth,
  required StripDrag drag,
}) {
  final state = drag.drawn ?? store.state;
  final music = state.project.music;
  final heard = state.project.heardMusic;
  if (state.selectedText != null || music == null || heard == null || heard <= core.Time.zero) {
    return const [];
  }
  final x = left + scale.x(core.Time.zero);
  final width = scale.width(heard);
  final writing = core.TimelineGeometry.writing(barX: x, barWidth: width, shownX: 0, shownWidth: shownWidth);
  return [
    Positioned(
      key: const ValueKey<String>('editor.music'),
      left: x,
      top: rows.musicY,
      width: width,
      height: rows.rowHeight,
      child: MusicBar(store: store, title: music.file.title, writingX: writing.x - x, writingWidth: writing.width),
    ),
  ];
}

/// The bar of the music row. It shows the title of the music, which is content and no word of the app, on the part
/// of the bar that is on the screen, from its left end, as the writing of a text bar does. A tap sends
/// `sound(open)`, and a drag that begins on it is a scrub of the strip.
///
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/widgets/DecoratedBox/position.html
/// https://api.flutter.dev/flutter/widgets/Text/overflow.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class MusicBar extends StatelessWidget {
  const MusicBar({
    super.key,
    required this.store,
    required this.title,
    required this.writingX,
    required this.writingWidth,
  });

  final EditorStore store;

  /// The title of the music, as given.
  final String title;

  /// Where the writing begins inside the bar, and how wide it may be.
  final double writingX;
  final double writingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = context.findAncestorWidgetOfExactType<EditorScreen>()?.words;
    final label = core.Words('musicRow.bar', [title]);
    // iOS's system teal at 35 percent.
    final teal = theme.brightness == Brightness.light ? const Color(0xFF30B0C7) : const Color(0xFF40C8E0);
    return Semantics(
      identifier: 'editor.music',
      container: true,
      button: true,
      label: words?.text(label) ?? label.key,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        // The strip's tap loses a tap on the bar, so it clears nothing.
        onTap: () => store.send(core.EditorAction.sound(core.SoundAction.open)),
        child: ColoredBox(
          color: teal.withValues(alpha: 0.35),
          child: DecoratedBox(
            // Painted above the writing, as m6's layer border.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: Border.all(width: 1, color: theme.scaffoldBackgroundColor)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (writingWidth > 0)
                  Positioned(
                    left: writingX,
                    top: 0,
                    bottom: 0,
                    width: writingWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
