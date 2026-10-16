import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';

/// The panel over the editor: the words of the export state, the percent while exporting, and one button
/// when the export has ended. While exporting it has no button, so there is no cancel.
/// The percent never mirrors: it is fixed left to right. On the saved panel the line `export.fileInfo` shows what
/// the written file holds, only when the button passes it.
///
/// https://api.flutter.dev/flutter/widgets/Directionality-class.html
/// https://api.flutter.dev/flutter/material/FilledButton-class.html
/// https://api.flutter.dev/flutter/widgets/PopScope-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class ExportPanel extends StatelessWidget {
  const ExportPanel({
    super.key,
    required this.state,
    required this.words,
    required this.fileInfo,
    required this.close,
  });

  final core.ExportState state;
  final WordsText words;
  final String? fileInfo;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stateWords = state.words;
    final percent = state.percentText;
    final fileInfo = this.fileInfo;
    // Only the panel's own buttons close it.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  if (stateWords != null)
                    _line('export.words', words.text(stateWords), const TextStyle(fontSize: 22)),
                  if (percent != null)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: _line('export.percent', percent, const TextStyle(fontSize: 34)),
                    ),
                  if (state == core.ExportState.saved && fileInfo != null)
                    _line('export.fileInfo', fileInfo, text.bodySmall),
                  if (state == core.ExportState.saved) _button('export.done', 'export.done'),
                  if (state is core.ExportStateFailed) _button('export.close', 'export.close'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String identifier, String line, TextStyle? style) {
    return Semantics(
      identifier: identifier,
      container: true,
      child: Text(line, textAlign: TextAlign.center, style: style),
    );
  }

  Widget _button(String identifier, String key) {
    final label = words.text(core.Words(key));
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      enabled: true,
      label: label,
      onTap: close,
      excludeSemantics: true,
      child: FilledButton(onPressed: close, child: Text(label)),
    );
  }
}
