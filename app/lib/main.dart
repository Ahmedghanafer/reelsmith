import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reelsmith_core/reelsmith_core.dart' as core;

import 'editor/editor_screen.dart';
import 'editor/editor_store.dart';
import 'engine/video_engine.dart';
import 'start/seed_start.dart';
import 'start/start_screen.dart';
import 'words/words.dart';

void main() {
  runApp(ReelsmithApp(engine: PigeonVideoEngine()));
}

/// The root of the app. The start screen goes into the slot `start`.
class ReelsmithApp extends StatelessWidget {
  const ReelsmithApp({super.key, required this.engine});

  final VideoEngine engine;

  @override
  Widget build(BuildContext context) {
    // slot: start
    // The language of her list that the app has, which gives the direction of every screen.
    // https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/locales.html
    // https://api.flutter.dev/flutter/material/MaterialApp/supportedLocales.html
    final locale = language(WidgetsBinding.instance.platformDispatcher.locales);
    return MaterialApp(
      locale: locale,
      supportedLocales: languages,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: StartRoot(engine: engine, locale: locale),
    );
    // end slot: start
  }
}

/// English, Arabic and Swedish, the languages of the word files, English first.
const List<Locale> languages = [Locale('en'), Locale('ar'), Locale('sv')];

/// The language as iOS picks it: down her list of preferred languages to the first the app has, English when
/// none of them is on it.
Locale language(List<Locale> preferred) {
  for (final locale in preferred) {
    for (final one in languages) {
      if (one.languageCode == locale.languageCode) {
        return one;
      }
    }
  }
  return languages.first;
}

/// What the root holds once `launch` came: its values, the shelf on the folder they name, and the words.
typedef _Launch = ({Map<String, Object?> options, core.DraftShelf shelf, WordsText words});

/// Reads the launch values, opens the shelf of drafts on the folder they give (with `drafts fresh` that folder
/// is emptied once), loads the words of the locale, and shows the start screen. A seed start opens the editor
/// unless one is open already. The editor is pushed over the start screen on a store, by the seed start and by
/// the start screen alike. Once the store is closed the editor is popped, the store disposed after that frame,
/// and the start screen made anew.
///
/// https://api.flutter.dev/flutter/widgets/Navigator/push.html
/// https://api.flutter.dev/flutter/widgets/PageRouteBuilder-class.html
/// https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html
class StartRoot extends StatefulWidget {
  const StartRoot({super.key, required this.engine, required this.locale});

  final VideoEngine engine;
  final Locale locale;

  @override
  State<StartRoot> createState() => _StartRootState();
}

class _StartRootState extends State<StartRoot> {
  _Launch? _launch;
  EditorStore? _store;

  /// Counts the closes of the editor: the key of the start screen, so each close makes it anew.
  int _starts = 0;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    final options = jsonDecode(await widget.engine.launch()) as Map<String, Object?>;
    final shelf = draftShelf(options);
    if (options['drafts'] == 'fresh') {
      try {
        shelf.removeAll();
      } catch (_) {}
    }
    final words = await WordsText.load(widget.locale);
    if (!mounted) {
      return;
    }
    setState(() => _launch = (options: options, shelf: shelf, words: words));
    final EditorStore? seeded;
    try {
      seeded = await seedStart(widget.engine, options, shelf);
    } catch (error) {
      print('seed start: the seed was not started: $error');
      return;
    }
    if (seeded != null) {
      _open(seeded);
    }
  }

  /// Pushes the editor on the store. One editor is open at a time: a store that comes while one is open is
  /// disposed.
  void _open(EditorStore store) {
    if (_store != null || !mounted) {
      store.dispose();
      return;
    }
    final words = _launch!.words;
    _store = store;
    final navigator = Navigator.of(context);
    final route = PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => EditorScreen(store: store, words: words),
    );
    void closed() {
      if (store.isOpen) {
        return;
      }
      store.removeListener(closed);
      // What the editor showed over itself goes with it.
      navigator.popUntil((one) => one == route);
      navigator.pop();
      // The editor leaves the tree in the next frame, and the store goes after it.
      WidgetsBinding.instance.addPostFrameCallback((_) => store.dispose());
      if (mounted) {
        setState(() {
          _store = null;
          _starts++;
        });
      }
    }

    store.addListener(closed);
    navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final launch = _launch;
    if (launch == null) {
      return const Scaffold(backgroundColor: Color(0xFFFFFFFF));
    }
    return StartScreen(
      key: ValueKey(_starts),
      engine: widget.engine,
      options: launch.options,
      shelf: launch.shelf,
      words: launch.words,
      open: _open,
    );
  }
}
