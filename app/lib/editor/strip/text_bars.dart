import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../editor_screen.dart';
import '../editor_store.dart';
import 'clip_press.dart';

/// As wide as a trim handle of a clip.
const double _handleWidth = 24;

/// The breaks that end a line, as Swift's `isNewline`.
final RegExp _lineBreak = RegExp('\r\n|[\n\r\u000B\u000C\u0085  ]');

/// The text row of the strip, for the slot `text-row`, `left` being the x of time zero and `shownWidth` the width of
/// the strip on the screen. One bar for every text with a range, in the row under the blocks, and the two handles of
/// the selected one outside its edges, none without one. Placed by the state the strip draws, so a bar follows the
/// edge a handle drags and the block a press moves. Never mirrored: every x is set from the left at the scale, and
/// the start handle is at the left edge in every language.
List<Widget> textBars({
  required EditorStore store,
  required core.TimelineScale scale,
  required core.StripRows rows,
  required double left,
  required double shownWidth,
  required StripDrag drag,
  required VoidCallback redraw,
}) {
  final state = drag.drawn ?? store.state;
  final project = state.project;
  final bars = <Widget>[];
  ({double x, double right})? selectedBar;
  for (final item in project.texts) {
    final range = project.range(item.id);
    if (range == null) {
      continue;
    }
    final x = left + scale.x(range.start);
    final width = scale.width(range.duration);
    final selected = item.id == state.selectedText;
    if (selected) {
      selectedBar = (x: x, right: x + width);
    }
    final writing = core.TimelineGeometry.writing(barX: x, barWidth: width, shownX: 0, shownWidth: shownWidth);
    bars.add(
      Positioned(
        key: ValueKey<core.TextID>(item.id),
        left: x,
        top: rows.textY,
        width: width,
        height: rows.rowHeight,
        child: TextBar(
          store: store,
          id: item.id,
          position: project.positionOfText(item.id) ?? 0,
          line: item.isBlank ? '' : item.string.split(_lineBreak).first,
          selected: selected,
          writingX: writing.x - x,
          writingWidth: writing.width,
        ),
      ),
    );
  }
  final bar = selectedBar;
  if (bar == null) {
    return bars;
  }
  return [
    ...bars,
    for (final isStart in const [true, false])
      Positioned(
        key: ValueKey<String>(isStart ? 'editor.textTrim.start' : 'editor.textTrim.end'),
        left: isStart ? bar.x - _handleWidth : bar.right,
        top: rows.textY,
        width: _handleWidth,
        height: rows.rowHeight,
        child: TextTrimHandle(isStart: isStart, store: store, scale: scale, drag: drag, redraw: redraw),
      ),
  ];
}

/// One bar of the text row: a text that has a range, drawn from its start for its length. It shows the first line of
/// the string, which is content and no word of the app, on the part of the bar that is on the screen, from its left
/// end. A tap selects its text, and a drag that begins on it is a scrub of the strip. It decides nothing: its place
/// comes from the scale, that of its writing from `TimelineGeometry`, the range and the position from `Project`.
///
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/widgets/DecoratedBox/position.html
/// https://api.flutter.dev/flutter/widgets/Text/overflow.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class TextBar extends StatelessWidget {
  const TextBar({
    super.key,
    required this.store,
    required this.id,
    required this.position,
    required this.line,
    required this.selected,
    required this.writingX,
    required this.writingWidth,
  });

  final EditorStore store;
  final core.TextID id;

  /// 1 for the first text of the project.
  final int position;

  /// The first line of the string, empty for a blank text.
  final String line;
  final bool selected;

  /// Where the writing begins inside the bar, and how wide it may be.
  final double writingX;
  final double writingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = context.findAncestorWidgetOfExactType<EditorScreen>()?.words;
    final label = core.Words('textRow.bar', ['$position']);
    return Semantics(
      identifier: 'editor.text.$position',
      container: true,
      label: words?.text(label) ?? label.key,
      value: line,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        // The strip's tap loses a tap on a bar, so it selects no clip and clears nothing.
        onTap: () => store.send(core.EditorAction.text(core.TextAction.select(id))),
        child: ColoredBox(
          // iOS's systemGray4.
          color: theme.disabledColor,
          child: DecoratedBox(
            // Painted above the writing, as m6's layer border.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                width: selected ? 3 : 1,
                color: selected
                    ? (theme.brightness == Brightness.light ? const Color(0xFFFFCC00) : const Color(0xFFFFD60A))
                    : theme.scaffoldBackgroundColor,
              ),
            ),
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
                        line,
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

/// One of the two handles of the selected text bar, outside its edge. It decides nothing: a drag draws `reduce` of
/// the state from its start with the trim for the points moved so far, and one trim action is sent on release, so a
/// trim is one step of undo. A tap on it does nothing, and a drag on it never scrubs: its recognizers take the touch
/// before the strip's.
///
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector/dragStartBehavior.html
/// https://api.flutter.dev/flutter/gestures/DragStartDetails-class.html
/// https://api.flutter.dev/flutter/gestures/DragUpdateDetails-class.html
/// https://api.flutter.dev/flutter/widgets/BuildContext/findAncestorWidgetOfExactType.html
class TextTrimHandle extends StatefulWidget {
  const TextTrimHandle({
    super.key,
    required this.isStart,
    required this.store,
    required this.scale,
    required this.drag,
    required this.redraw,
  });

  final bool isStart;
  final EditorStore store;
  final core.TimelineScale scale;
  final StripDrag drag;

  /// Draws the strip again.
  final VoidCallback redraw;

  @override
  State<TextTrimHandle> createState() => _TextTrimHandleState();
}

class _TextTrimHandleState extends State<TextTrimHandle> {
  /// The state at the start of the drag, null while no drag runs.
  core.EditorState? _start;

  /// The x on the screen where the finger came down.
  double _fingerStartX = 0;

  /// The points moved at the last step.
  double _moved = 0;

  @override
  Widget build(BuildContext context) {
    final key = widget.isStart ? 'textRow.trimStart' : 'textRow.trimEnd';
    final words = context.findAncestorWidgetOfExactType<EditorScreen>()?.words;
    final light = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      identifier: widget.isStart ? 'editor.textTrim.start' : 'editor.textTrim.end',
      container: true,
      label: words?.text(core.Words(key)) ?? key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        dragStartBehavior: DragStartBehavior.down,
        // A tap on a handle does nothing. Without it the strip's tap would clear the selection.
        onTap: () {},
        onHorizontalDragStart: _began,
        onHorizontalDragUpdate: (details) => _step(details.globalPosition.dx - _fingerStartX),
        onHorizontalDragEnd: (_) => _ended(),
        onHorizontalDragCancel: _cancelled,
        // iOS's system yellow.
        child: ColoredBox(color: light ? const Color(0xFFFFCC00) : const Color(0xFFFFD60A)),
      ),
    );
  }

  core.EditorAction _action(core.TextID text, double moved) {
    final scale = widget.scale;
    return core.EditorAction.text(
      widget.isStart
          ? core.TextAction.trimStart(text, scale.trimAmount(moved))
          : core.TextAction.trimEnd(text, scale.trimAmount(-moved)),
    );
  }

  /// The drag starts by sending `pause`, so the state of the store stands still under the preview.
  void _began(DragStartDetails details) {
    final store = widget.store;
    store.send(core.EditorAction.pause);
    _start = core.reduce(store.state, core.EditorAction.pause);
    _fingerStartX = details.globalPosition.dx;
    _step(0);
  }

  void _step(double moved) {
    final start = _start;
    final text = start?.selectedText;
    if (start == null || text == null) {
      return;
    }
    _moved = moved;
    widget.drag.draw(core.reduce(start, _action(text, moved)));
    widget.redraw();
  }

  void _ended() {
    final text = _start?.selectedText;
    _start = null;
    if (text == null) {
      return;
    }
    widget.drag.draw(null);
    widget.redraw();
    widget.store.send(_action(text, _moved));
  }

  /// A cancelled drag draws the state of the store again and sends nothing.
  void _cancelled() {
    if (_start == null) {
      return;
    }
    _start = null;
    widget.drag.draw(null);
    widget.redraw();
  }
}
