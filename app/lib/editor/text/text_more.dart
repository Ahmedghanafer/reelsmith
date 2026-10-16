import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'text_look.dart';
import 'text_panel.dart';

/// More of the selected text: a row of the three sides of `TextAlign`, a slider for the line spacing and a row of
/// three toggles for the outline, the shadow and the box. It decides nothing and holds no state: a control shows
/// what the style of the selected text holds, and sends `setStyle` with that whole style changed in one value. Core
/// holds the line spacing between its limits. The alignment is a side of the picture, so its row is laid out from
/// left to right in every language. The slider and the toggles lay out from leading to trailing, so Arabic mirrors
/// them.
///
/// https://api.flutter.dev/flutter/material/Slider-class.html
/// https://api.flutter.dev/flutter/widgets/Directionality-class.html
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class TextMore extends StatelessWidget {
  const TextMore({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  Widget build(BuildContext context) {
    final id = store.state.selectedText;
    final selected = id == null ? null : store.state.project.text(id);
    if (selected == null) {
      return const SizedBox.shrink();
    }
    final style = selected.style;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              for (final align in core.TextAlign.allCases)
                Expanded(
                  child: textButton(
                    'text.align.${align.rawValue}',
                    words.text(core.Words('text.align.${align.rawValue}')),
                    style.align == align,
                    () => _change(selected.id, (style) => style.copyWith(align: align)),
                  ),
                ),
            ],
          ),
        ),
        Row(
          spacing: 16,
          children: [
            Text(words.text(core.Words('text.spacing'))),
            Expanded(
              child: textSlider(
                'text.spacing',
                words.text(core.Words('text.spacing')),
                Slider(
                  value: style.lineSpacing,
                  // The track past the thumb in the grey of the theme, as the iOS slider draws it.
                  inactiveColor: Theme.of(context).disabledColor,
                  max: 2,
                  divisions: 20,
                  onChanged: (spacing) => _change(selected.id, (style) => style.copyWith(lineSpacing: spacing)),
                ),
                style.lineSpacing / 2,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            spacing: 8,
            children: [
              _mark(
                context,
                'text.outline',
                style.outline,
                () => _change(selected.id, (style) => style.copyWith(outline: !style.outline)),
              ),
              _mark(
                context,
                'text.shadow',
                style.shadow,
                () => _change(selected.id, (style) => style.copyWith(shadow: !style.shadow)),
              ),
              _mark(context, 'text.box', style.box, () => _change(selected.id, (style) => style.copyWith(box: !style.box))),
            ],
          ),
        ),
      ],
    );
  }

  /// One toggle drawn as a button as wide as its third of the row, tinted while it is on, which a tap anywhere on
  /// turns. Its word key is its identifier. The tap turns the mark the text has at the call, so two quick taps turn
  /// it twice.
  Widget _mark(BuildContext context, String key, bool isOn, VoidCallback turn) {
    final scheme = Theme.of(context).colorScheme;
    final label = words.text(core.Words(key));
    return Expanded(
      child: Semantics(
        identifier: key,
        container: true,
        button: true,
        selected: isOn,
        label: label,
        onTap: turn,
        excludeSemantics: true,
        child: TextButton(
          onPressed: turn,
          style: TextButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(0, 44),
            backgroundColor: isOn ? scheme.primary.withValues(alpha: 0.15) : null,
            textStyle: const TextStyle(fontSize: 17),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  /// Sends the style the text has at the call, changed in one value.
  void _change(core.TextID id, core.TextStyle Function(core.TextStyle) edit) {
    final style = store.state.project.text(id)?.style;
    if (style == null) {
      return;
    }
    store.send(core.EditorAction.text(core.TextAction.setStyle(id, edit(style))));
  }
}
