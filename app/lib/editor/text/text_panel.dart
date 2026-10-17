import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';
import '../editor_store.dart';
import 'text_look.dart';
import 'text_more.dart';

/// The panel of the selected text: one row with the three part buttons and, at its trailing end, the done button,
/// and under the row the part that shows. Which part shows is the one state of the panel: type when the text is
/// blank at the moment the panel is made for it, look otherwise. Everything else is the state of the store. The done
/// button only clears the selection, and Core removes a text that is left blank. The row lays out from leading to
/// trailing, so Arabic mirrors it.
///
/// While the keyboard is up the row of part buttons is only as high as its words and the panel has no space under
/// it, so the picture keeps its room above the panel, as in m6.
///
/// The field shows the string of the store and sends every change of it whole. It starts each sentence with a
/// capital, and takes its direction from the first letter of what is typed, so an Arabic text stands at the right.
/// A change that would leave half of a character (an unpaired UTF-16 surrogate) has that half taken out first, since
/// the draft could not be read back.
///
/// https://api.flutter.dev/flutter/material/TextField-class.html
/// https://api.flutter.dev/flutter/widgets/TextEditingController-class.html
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class TextPanel extends StatefulWidget {
  const TextPanel({super.key, required this.store, required this.words});

  final EditorStore store;
  final WordsText words;

  @override
  State<TextPanel> createState() => _TextPanelState();
}

enum _Part { type, look, more }

class _TextPanelState extends State<TextPanel> {
  late _Part _part;
  late final TextEditingController _field;

  EditorStore get store => widget.store;

  core.TextItem? get _selected {
    final state = store.state;
    final id = state.selectedText;
    return id == null ? null : state.project.text(id);
  }

  @override
  void initState() {
    super.initState();
    final selected = _selected;
    _part = selected != null && selected.isBlank ? _Part.type : _Part.look;
    _field = TextEditingController(text: selected?.string ?? '');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final rowHeight = typing ? 0.0 : 44.0;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: typing ? 0 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowHeight),
            child: Row(
              spacing: 24,
              children: [
                _tab(_Part.type, 'text.tab.type', rowHeight),
                _tab(_Part.look, 'text.tab.look', rowHeight),
                _tab(_Part.more, 'text.tab.more', rowHeight),
                const Spacer(),
                textButton(
                  'text.done',
                  widget.words.text(core.Words('text.done')),
                  null,
                  () => store.send(core.EditorAction.clearSelection),
                  height: rowHeight,
                ),
              ],
            ),
          ),
          if (_part == _Part.type && selected != null) _typed(context, selected),
          if (_part == _Part.look) TextLook(store: store, words: widget.words),
          if (_part == _Part.more) TextMore(store: store, words: widget.words),
        ],
      ),
    );
  }

  /// One part button. Its word key is its identifier, and the part that shows is bold and has the trait selected.
  Widget _tab(_Part shown, String key, double height) {
    return textButton(
      key,
      widget.words.text(core.Words(key)),
      _part == shown,
      () => setState(() => _part = shown),
      height: height,
    );
  }

  Widget _typed(BuildContext context, core.TextItem selected) {
    // An undo or a redo changes the string under the field: the field shows the string of the store.
    if (_field.text != selected.string) {
      _field.value = TextEditingValue(
        text: selected.string,
        selection: TextSelection.collapsed(offset: selected.string.length),
      );
    }
    return SizedBox(
      height: 88,
      child: Semantics(
        identifier: 'text.field',
        label: widget.words.text(core.Words('text.field')),
        child: TextField(
          controller: _field,
          maxLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          textDirection: fieldDirection(selected.string),
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(8),
            enabledBorder: _border(context),
            focusedBorder: _border(context),
          ),
          onChanged: (string) {
            final kept = whole(string);
            if (kept != string) {
              // The caret keeps its place in what is kept.
              final offset = _field.selection.baseOffset.clamp(0, string.length);
              _field.value = TextEditingValue(
                text: kept,
                selection: TextSelection.collapsed(offset: whole(string.substring(0, offset)).length),
              );
            }
            store.send(core.EditorAction.text(core.TextAction.setString(selected.id, kept)));
          },
        ),
      ),
    );
  }

  OutlineInputBorder _border(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    );
  }
}

/// The string without any UTF-16 surrogate that is not one half of a pair.
String whole(String string) {
  final units = string.codeUnits;
  final kept = <int>[];
  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    if (isHigh && index + 1 < units.length && units[index + 1] >= 0xDC00 && units[index + 1] <= 0xDFFF) {
      kept
        ..add(unit)
        ..add(units[index + 1]);
      index++;
    } else if (!isHigh && !isLow) {
      kept.add(unit);
    }
  }
  return kept.length == units.length ? string : String.fromCharCodes(kept);
}

/// Right to left when the first letter of the string is Arabic or Hebrew, left to right when it is a Latin letter,
/// and null, the direction of the language, when the string has no letter.
TextDirection? fieldDirection(String string) {
  for (final rune in string.runes) {
    if ((rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A) || (rune >= 0xC0 && rune <= 0x24F)) {
      return TextDirection.ltr;
    }
  }
  return null;
}

/// A button of words with its identifier, the label of its word, the trait selected when `selected` is true and
/// bold words then. `selected` null is a button that is never selected. On iOS Material pads a button to a 48 point
/// target, so the target is shrink wrapped and the height held at `height`, 44 unless the caller says otherwise.
Widget textButton(String identifier, String label, bool? selected, VoidCallback tap, {double height = 44}) {
  return Semantics(
    identifier: identifier,
    container: true,
    button: true,
    selected: selected,
    label: label,
    onTap: tap,
    excludeSemantics: true,
    child: TextButton(
      onPressed: tap,
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        minimumSize: Size(0, height),
        textStyle: TextStyle(fontSize: 17, fontWeight: selected == true ? FontWeight.bold : FontWeight.normal),
      ),
      child: Text(label),
    ),
  );
}
