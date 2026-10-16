import 'package:flutter/material.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import '../../words/words.dart';

/// The choice of size and rate, in the sheet of the button `editor.exportSettings`. It decides nothing and holds no
/// state: a button shows the words of its case from Core, the chosen one has the trait selected and a filled
/// background, and a tap sends the settings `choosing` that case. Every button is always shown and a choice
/// changes no weight or size, so the sheet has one height and no button moves. The rows lay out from leading to
/// trailing, so Arabic mirrors them.
///
/// https://api.flutter.dev/flutter/material/TextButton-class.html
/// https://api.flutter.dev/flutter/material/FilledButton-class.html
/// https://api.flutter.dev/flutter/widgets/Expanded-class.html
/// https://api.flutter.dev/flutter/widgets/Semantics-class.html
class ExportSettingsSheet extends StatelessWidget {
  const ExportSettingsSheet({
    super.key,
    required this.settings,
    required this.words,
    required this.choose,
    required this.done,
  });

  final core.ExportSettings settings;
  final WordsText words;
  final void Function(core.ExportSettings) choose;
  final VoidCallback done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(words.text(const core.Words('export.settings')), style: text.titleMedium),
            Text(words.text(const core.Words('export.size'))),
            Row(
              spacing: 8,
              children: [
                for (final size in core.ExportSize.allCases)
                  _choice(context, size.words, 'export.size.${size.name}', settings.size == size, () => settings.choosingSize(size)),
              ],
            ),
            Text(words.text(const core.Words('export.rate'))),
            Row(
              spacing: 8,
              children: [
                for (final rate in core.ExportRate.allCases)
                  _choice(context, rate.words, 'export.rate.${rate.name}', settings.rate == rate, () => settings.choosingRate(rate)),
              ],
            ),
            Semantics(
              identifier: 'export.settingsDone',
              container: true,
              button: true,
              enabled: true,
              label: words.text(const core.Words('export.settings.done')),
              onTap: done,
              excludeSemantics: true,
              child: FilledButton(onPressed: done, child: Text(words.text(const core.Words('export.settings.done')))),
            ),
          ],
        ),
      ),
    );
  }

  /// One button as wide as its share of the row. The identifier names the case, as `export.size.hd720`.
  Widget _choice(BuildContext context, core.Words caseWords, String identifier, bool chosen, core.ExportSettings Function() next) {
    final label = words.text(caseWords);
    void tap() => choose(next());
    return Expanded(
      child: Semantics(
        identifier: identifier,
        container: true,
        button: true,
        enabled: true,
        selected: chosen,
        label: label,
        onTap: tap,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chosen ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed: tap,
            style: TextButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
            ),
            child: Text(label, maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}
