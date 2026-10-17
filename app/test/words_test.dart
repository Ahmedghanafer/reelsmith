import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:reelsmith/words/words.dart';
import 'package:reelsmith_core/reelsmith_core.dart';

/// The lines of one word file, read line by line apart from the loader. Every line that starts with a quote must be one.
Map<String, String> fileLines(String language) {
  final line = RegExp(r'^"([^"]*)" = "([^"]*)";$');
  final lines = <String, String>{};
  for (final text in File('assets/words/$language.lproj/Localizable.strings').readAsLinesSync()) {
    if (text.trim().startsWith('"')) {
      final match = line.firstMatch(text.trim());
      expect(match, isNotNull, reason: '$language $text');
      lines[match!.group(1)!] = match.group(2)!;
    }
  }
  return lines;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each key gives its line in English, Arabic and Swedish', () async {
    for (final language in ['en', 'ar', 'sv']) {
      final words = await WordsText.load(Locale(language));
      final lines = fileLines(language);
      expect(lines, isNotEmpty, reason: language);
      for (final entry in lines.entries) {
        expect(words.text(Words(entry.key)), entry.value, reason: '$language ${entry.key}');
      }
    }
    expect((await WordsText.load(const Locale('en'))).text(Words('start.newProject')), 'New project');
    expect((await WordsText.load(const Locale('ar'))).text(Words('start.newProject')), 'مشروع جديد');
    expect((await WordsText.load(const Locale('sv'))).text(Words('start.newProject')), 'Nytt projekt');
  });

  test('the language comes from the locale, English for any other', () async {
    expect((await WordsText.load(const Locale('ar', 'SA'))).text(Words('export.saved')), 'تم الحفظ في الصور');
    expect((await WordsText.load(const Locale('sv', 'SE'))).text(Words('export.saved')), 'Sparad i Bilder');
    expect((await WordsText.load(const Locale('fr'))).text(Words('export.saved')), 'Saved to Photos');
  });

  test('the arguments go in at %1\$@ and %2\$@ for each key that has them', () async {
    final expected = {
      'en': {
        'editor.seedInfo': '3 clips, 4 files',
        'text.colour': 'Colour 2',
        'textRow.bar': 'Text 1',
        'drafts.row': 'Project of 16 Oct 2026, 0:12 long',
        'musicRow.bar': 'Music 5',
      },
      'ar': {
        'editor.seedInfo': 'المقاطع: 3، الملفات: 4',
        'text.colour': 'اللون 2',
        'textRow.bar': 'النص 1',
        'drafts.row': 'مشروع بتاريخ 16 Oct 2026، مدته 0:12',
        'musicRow.bar': 'الموسيقى 5',
      },
      'sv': {
        'editor.seedInfo': '3 klipp, 4 filer',
        'text.colour': 'Färg 2',
        'textRow.bar': 'Text 1',
        'drafts.row': 'Projekt från 16 Oct 2026, 0:12 långt',
        'musicRow.bar': 'Musik 5',
      },
    };
    final arguments = {
      'editor.seedInfo': ['3', '4'],
      'text.colour': ['2'],
      'textRow.bar': ['1'],
      'drafts.row': ['16 Oct 2026', '0:12'],
      'musicRow.bar': ['5'],
    };
    for (final language in expected.keys) {
      final words = await WordsText.load(Locale(language));
      for (final key in arguments.keys) {
        expect(words.text(Words(key, arguments[key]!)), expected[language]![key], reason: '$language $key');
      }
    }
  });
}
