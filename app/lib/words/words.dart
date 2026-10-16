import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:reelsmith_core/reelsmith_core.dart';

/// The words of one language, read from its `Localizable.strings` in `assets/words/`.
///
/// https://api.flutter.dev/flutter/services/rootBundle.html
class WordsText {
  WordsText(Map<String, String> lines) : _lines = Map<String, String>.unmodifiable(lines);

  final Map<String, String> _lines;

  /// Reads the file of the locale's language: English, Arabic or Swedish, and English for any other.
  static Future<WordsText> load(Locale locale) async {
    final language = const ['en', 'ar', 'sv'].contains(locale.languageCode) ? locale.languageCode : 'en';
    return WordsText(parseStrings(await rootBundle.loadString('assets/words/$language.lproj/Localizable.strings')));
  }

  /// The line of the key, with the arguments put in at %1$@, %2$@ and so on. A key with no line gives the key, as on iOS.
  String text(Words words) {
    var result = _lines[words.key] ?? words.key;
    for (var index = 0; index < words.arguments.length; index++) {
      result = result.replaceAll('%${index + 1}\$@', words.arguments[index]);
    }
    return result;
  }
}

/// The `"key" = "value";` lines of a `.strings` file. Comments are skipped, and a backslash keeps the quote or backslash after it, or makes `\n` a new line.
Map<String, String> parseStrings(String source) {
  final lines = <String, String>{};
  String? key;
  var index = 0;
  while (index < source.length) {
    if (source.startsWith('/*', index)) {
      final end = source.indexOf('*/', index + 2);
      index = end < 0 ? source.length : end + 2;
    } else if (source.startsWith('//', index)) {
      final end = source.indexOf('\n', index);
      index = end < 0 ? source.length : end + 1;
    } else if (source[index] == '"') {
      final quoted = StringBuffer();
      index++;
      while (index < source.length && source[index] != '"') {
        if (source[index] == '\\' && index + 1 < source.length) {
          index++;
          quoted.write(source[index] == 'n' ? '\n' : source[index]);
        } else {
          quoted.write(source[index]);
        }
        index++;
      }
      index++;
      if (key == null) {
        key = quoted.toString();
      } else {
        lines[key] = quoted.toString();
        key = null;
      }
    } else {
      index++;
    }
  }
  return lines;
}
