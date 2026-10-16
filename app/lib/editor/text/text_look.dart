import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'text_panel.dart';

/// The look of the selected text: a row of the faces of `TextFont` by their words, a row of the colours of
/// `TextStyle.palette` and a slider for the size. It decides nothing and holds no state: a control shows what the
/// style of the selected text holds, and sends `setStyle` with that whole style changed in one value. Core holds the
/// size between its limits, and the slider takes its two ends from Core. The rows lay out from leading to trailing,
/// so Arabic mirrors them.
///
/// https://api.flutter.dev/flutter/material/Slider-class.html
/// https://api.flutter.dev/flutter/widgets/FittedBox-class.html
/// https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
/// https://api.flutter.dev/flutter/painting/BoxDecoration-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class TextLook extends StatelessWidget {
  const TextLook({super.key, required this.store, required this.words});

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
    final palette = core.TextStyle.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        // Scaled down whole on a screen too narrow for the row, never cut.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                for (final font in core.TextFont.allCases)
                  textButton(
                    'text.font.${font.rawValue}',
                    words.text(font.words),
                    style.font == font,
                    () => _change(selected.id, (style) => style.copyWith(font: font)),
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            for (var index = 0; index < palette.length; index++)
              Expanded(child: _swatch(context, index, palette[index], style.colour == palette[index], selected.id)),
          ],
        ),
        Row(
          spacing: 16,
          children: [
            Text(words.text(core.Words('text.size'))),
            Expanded(
              child: textSlider(
                'text.size',
                words.text(core.Words('text.size')),
                Slider(
                  value: style.size,
                  min: core.TextGeometry.minimumSize,
                  max: core.TextGeometry.maximumSize,
                  divisions: (core.TextGeometry.maximumSize - core.TextGeometry.minimumSize) ~/ 2,
                  onChanged: (size) => _change(selected.id, (style) => style.copyWith(size: size)),
                ),
                (style.size - core.TextGeometry.minimumSize) /
                    (core.TextGeometry.maximumSize - core.TextGeometry.minimumSize),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One colour button: a disc of the colour, with a ring around it when the text has that colour. Its label names
  /// it by its number in the palette, counted from 1.
  Widget _swatch(BuildContext context, int index, core.RGB colour, bool isChosen, core.TextID id) {
    final scheme = Theme.of(context).colorScheme;
    void tap() => _change(id, (style) => style.copyWith(colour: colour));
    return Semantics(
      identifier: 'text.colour.${index + 1}',
      container: true,
      button: true,
      selected: isChosen,
      label: words.text(core.Words('text.colour', ['${index + 1}'])),
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isChosen ? scheme.primary : Colors.transparent, width: 3),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromARGB(255, colour.r, colour.g, colour.b),
                  border: Border.all(color: scheme.outline),
                ),
              ),
            ),
          ),
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

/// A slider with its identifier and the label of its word. Its value is the place of the thumb in percent, as iOS
/// gives it for a slider.
Widget textSlider(String identifier, String label, Slider slider, double share) {
  return Semantics(
    identifier: identifier,
    container: true,
    slider: true,
    label: label,
    value: '${(share * 100).round()}%',
    excludeSemantics: true,
    child: slider,
  );
}
