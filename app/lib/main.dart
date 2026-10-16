import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'engine/video_engine.dart';
import 'start/start_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The semantics tree is always built, so the UI tests read the identifiers.
  // https://api.flutter.dev/flutter/semantics/SemanticsBinding/ensureSemantics.html
  SemanticsBinding.instance.ensureSemantics();
  runApp(ReelsmithApp(engine: PigeonVideoEngine()));
}

/// The root of the app. The start screen goes into the slot `start`.
class ReelsmithApp extends StatelessWidget {
  const ReelsmithApp({super.key, required this.engine});

  final VideoEngine engine;

  @override
  Widget build(BuildContext context) {
    // slot: start
    // The language of her list that the app has, which gives the direction of every screen. A light and a
    // dark theme, chosen by the system appearance as in m6.
    // https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/locales.html
    // https://api.flutter.dev/flutter/material/MaterialApp/supportedLocales.html
    // https://api.flutter.dev/flutter/material/MaterialApp/darkTheme.html
    final locale = language(WidgetsBinding.instance.platformDispatcher.locales);
    return MaterialApp(
      locale: locale,
      supportedLocales: languages,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      home: StartRoot(engine: engine, locale: locale),
    );
    // end slot: start
  }
}
