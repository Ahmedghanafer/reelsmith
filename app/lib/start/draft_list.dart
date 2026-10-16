import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../engine/video_engine.dart';
import '../words/words.dart';

/// iOS's `systemRed`, the colour of a destructive swipe button.
const Color _red = Color(0xFFFF3B30);

/// The width of the button `drafts.delete` once the swipe has shown it whole.
const double _deleteWidth = 88;

/// The list of her drafts on the start screen, in the order given, moved from `App/Start/DraftList.swift`. It
/// decides nothing. Row n, counted from 1, is a button with the identifier `drafts.row.<n>`: a box of 64 by 64
/// points with the cover fitted whole on black, empty when the draft has no cover or the file is no picture, then
/// for a readable draft the date of its last write over its length, both fixed left to right, and for an
/// unreadable one the words of `drafts.unreadable`, disabled. So every row has one height whatever its cover. A
/// tap on a readable row calls `open`. A swipe towards the leading edge, on an unreadable row too, shows the
/// destructive button `drafts.delete` at the trailing edge, never a delete by a full swipe alone, and a tap on any
/// row while it shows only closes it. Its tap asks through `confirm`, the system alert of Swift, and only the
/// destructive answer calls `delete`. Its state is the row swiped and how far.
///
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/gestures/DragUpdateDetails/primaryDelta.html
/// https://api.flutter.dev/flutter/gestures/DragEndDetails/primaryVelocity.html
/// https://api.flutter.dev/flutter/widgets/Transform/Transform.translate.html
/// https://api.flutter.dev/flutter/widgets/Image/Image.file.html
/// https://api.flutter.dev/flutter/painting/FileImage-class.html
/// https://api.flutter.dev/flutter/painting/ImageProvider/evict.html
/// https://api.flutter.dev/flutter/widgets/Directionality-class.html
class DraftList extends StatefulWidget {
  const DraftList({
    super.key,
    required this.summaries,
    required this.shelf,
    required this.engine,
    required this.words,
    required this.enabled,
    required this.open,
    required this.delete,
  });

  final List<core.DraftSummary> summaries;

  /// For the cover files.
  final core.DraftShelf shelf;

  /// For `confirm`.
  final VideoEngine engine;
  final WordsText words;

  /// False while a new project is copied, so no other draft opens.
  final bool enabled;
  final void Function(core.DraftID id) open;
  final void Function(core.DraftID id) delete;

  @override
  State<DraftList> createState() => _DraftListState();
}

class _DraftListState extends State<DraftList> {
  core.DraftID? _swiped;

  /// How much of `drafts.delete` the swiped row shows, from 0 to `_deleteWidth`.
  double _shown = 0;

  @override
  void initState() {
    super.initState();
    // A leave writes the cover over the same file, so a picture kept from an earlier list would be the old one.
    for (final summary in widget.summaries) {
      FileImage(widget.shelf.coverFile(summary.id)).evict();
    }
  }

  String _text(core.Words words) => widget.words.text(words);

  void _close() => setState(() {
    _swiped = null;
    _shown = 0;
  });

  /// The swipe moves towards the leading edge to show the button: to the left, in Arabic to the right.
  double _towardsLeading(double delta) => Directionality.of(context) == TextDirection.rtl ? delta : -delta;

  Future<void> _ask(core.DraftID id) async {
    _close();
    bool confirmed;
    try {
      confirmed = await widget.engine.confirm(
        _text(core.Words('drafts.deleteQuestion')),
        _text(core.Words('drafts.delete')),
        _text(core.Words('drafts.deleteCancel')),
      );
    } catch (error) {
      print('drafts: the delete question was not shown: $error');
      confirmed = false;
    }
    if (confirmed && mounted) {
      widget.delete(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (place, summary) in widget.summaries.indexed) ...[
          if (place > 0) const Divider(height: 1),
          _row(place, summary),
        ],
      ],
    );
  }

  Widget _row(int place, core.DraftSummary summary) {
    final shown = summary.id == _swiped ? _shown : 0.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final changed = summary.changed;
    final opens = widget.enabled && summary.isReadable;
    final words = changed != null
        ? _text(core.Words('drafts.row', [core.dateText(changed, inUtc: false), summary.duration.clockText]))
        : _text(core.Words('drafts.unreadable'));
    final cover = widget.shelf.coverFile(summary.id);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: summary.hasCover
                  ? Image.file(cover, fit: BoxFit.contain, errorBuilder: (context, error, stack) => const SizedBox())
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          if (changed != null) ...[
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(core.dateText(changed, inUtc: false)),
                  const SizedBox(height: 4),
                  Text(summary.duration.clockText),
                ],
              ),
            ),
            const Spacer(),
          ] else
            Expanded(
              child: Text(
                _text(core.Words('drafts.unreadable')),
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
      ),
    );
    void tapped() {
      if (_swiped != null) {
        _close();
      } else if (opens) {
        widget.open(summary.id);
      }
    }

    return ClipRect(
      child: GestureDetector(
        excludeFromSemantics: true,
        onHorizontalDragStart: widget.enabled
            ? (_) => setState(() {
                if (_swiped != summary.id) {
                  _swiped = summary.id;
                  _shown = 0;
                }
              })
            : null,
        onHorizontalDragUpdate: widget.enabled
            ? (details) => setState(() {
                _shown = (_shown + _towardsLeading(details.primaryDelta ?? 0)).clamp(0.0, _deleteWidth);
              })
            : null,
        onHorizontalDragEnd: widget.enabled
            ? (details) {
                final velocity = _towardsLeading(details.primaryVelocity ?? 0);
                if (velocity > 300 || (velocity > -300 && _shown > _deleteWidth / 2)) {
                  setState(() => _shown = _deleteWidth);
                } else {
                  _close();
                }
              }
            : null,
        child: Stack(
          children: [
            if (shown > 0)
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Semantics(
                    identifier: 'drafts.delete',
                    container: true,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _ask(summary.id),
                      child: SizedBox(
                        width: shown,
                        height: double.infinity,
                        child: ColoredBox(
                          color: _red,
                          child: Center(
                            child: Text(
                              _text(core.Words('drafts.delete')),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(fontSize: 17, color: Color(0xFFFFFFFF)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(rtl ? shown : -shown, 0),
              child: Semantics(
                identifier: 'drafts.row.${place + 1}',
                container: true,
                button: true,
                enabled: opens,
                label: words,
                onTap: tapped,
                excludeSemantics: true,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTap: tapped,
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
