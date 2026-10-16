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
/// trailing, so Arabic mirrors it. While the keyboard is up the panel stands on a space as high as the keyboard, so
/// the field stays above it.
///
/// The field shows the string of the store and sends every change of it whole. A change that would leave half of a
/// character (an unpaired UTF-16 surrogate) has that half taken out first, since the draft could not be read back.
///
/// https://api.flutter.dev/flutter/material/TextField-class.html
/// https://api.flutter.dev/flutter/widgets/TextEditingController-class.html
/// https://api.flutter.dev/flutter/widgets/MediaQuery/viewInsetsOf.html
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
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              spacing: 24,
              children: [
                _tab(_Part.type, 'text.tab.type'),
                _tab(_Part.look, 'text.tab.look'),
                _tab(_Part.more, 'text.tab.more'),
                const Spacer(),
                textButton(
                  'text.done',
                  widget.words.text(core.Words('text.done')),
                  null,
                  () => store.send(core.EditorAction.clearSelection),
                ),
              ],
            ),
          ),
          if (_part == _Part.type && selected != null) _typed(context, selected),
          if (_part == _Part.look) TextLook(store: store, words: widget.words),
          if (_part == _Part.more) TextMore(store: store, words: widget.words),
          SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
        ],
      ),
    );
  }

  /// One part button. Its word key is its identifier, and the part that shows is bold and has the trait selected.
  Widget _tab(_Part shown, String key) {
    return textButton(key, widget.words.text(core.Words(key)), _part == shown, () => setState(() => _part = shown));
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

/// A button of words with its identifier, the label of its word, the trait selected when `selected` is true and
/// bold words then. `selected` null is a button that is never selected. On iOS Material pads a button to a 48 point
/// target, so the target is shrink wrapped and the height held at 44.
Widget textButton(String identifier, String label, bool? selected, VoidCallback tap) {
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
        minimumSize: const Size(0, 44),
        textStyle: TextStyle(fontSize: 17, fontWeight: selected == true ? FontWeight.bold : FontWeight.normal),
      ),
      child: Text(label),
    ),
  );
}
