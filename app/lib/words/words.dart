import 'dart:ui' show Locale;

import 'package:reelsmith_core/reelsmith_core.dart';

class WordsText {
  static Future<WordsText> load(Locale locale) async => WordsText();

  String text(Words words) => words.key;
}
